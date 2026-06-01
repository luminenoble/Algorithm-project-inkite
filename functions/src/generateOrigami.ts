import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/v2";
import { defineSecret } from "firebase-functions/params";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";

const STYLES = ["zen", "steampunk", "ink"] as const;
type Style = (typeof STYLES)[number];

/**
 * Replicate API token via Firebase Functions Secrets。
 * 设置：`firebase functions:secrets:set REPLICATE_API_TOKEN`
 * 未设置时 live 路径会抛错并降级回预生成池。
 */
const REPLICATE_API_TOKEN = defineSecret("REPLICATE_API_TOKEN");

interface GenerateRequest {
  challengeId: string;
  style?: string;
  /**
   * true → 走 Replicate Flux Schnell 实拍（T1.8b），失败自动回退预生成池。
   * false / 缺省 → 直接预生成池（T1.8a，默认零成本路径）。
   */
  live?: boolean;
  /**
   * Emulator 模式下手动传入测试 uid（生产由 request.auth 提供）。
   * 与 recompute.ts 「emulator 跳过 auth」对齐。
   */
  __testUid?: string;
}

interface GenerateResponse {
  origamiId: string;
  imageUrl: string;
  style: string;
  source: "pregen" | "flux";
}

/**
 * 折纸生成 Callable：完成官方挑战后客户端调用拿到一件折纸藏品。
 *
 * **默认路径（T1.8a）**：从 Cloud Storage `origami/pool/{style}/` 随机选图。
 * **备用路径（T1.8b）**：`live: true` 时调 Replicate Flux Schnell 实拍；
 *   失败/超时自动回退预生成池，保证演示弱网不阻塞。
 *
 * **防刷**：必须有该 uid 的 mode='official' + 对应 challengeId + publishedToSquare=true 的 story。
 * **幂等**：同 (uid, challengeId) 重复调用返回首次发放的同一条记录。
 */
export const generateOrigami = onCall<GenerateRequest>(
  { secrets: [REPLICATE_API_TOKEN] },
  async (request): Promise<GenerateResponse> => {
    const isEmulator = process.env.FUNCTIONS_EMULATOR === "true";
    const uid =
      request.auth?.uid ??
      (isEmulator ? request.data.__testUid : undefined);

    if (!uid) {
      throw new HttpsError(
        "unauthenticated",
        "需要登录（emulator 模式可在 data 传 __testUid）",
      );
    }

    const { challengeId, style: requestedStyle, live } = request.data;
    if (!challengeId || typeof challengeId !== "string") {
      throw new HttpsError("invalid-argument", "缺少 challengeId");
    }

    const db = getFirestore();

    // 1. 防刷校验：扫该用户的 stories（authorId 单字段索引），
    //    在内存里筛 official + challengeId + publishedToSquare。
    //    单 demo 用户至多十几篇官方故事，全量拉无成本压力。
    const ownStories = await db
      .collection("stories")
      .where("authorId", "==", uid)
      .get();

    const hasEligible = ownStories.docs.some((d) => {
      const data = d.data();
      return (
        data.mode === "official" &&
        data.challengeId === challengeId &&
        data.publishedToSquare === true
      );
    });

    if (!hasEligible) {
      throw new HttpsError(
        "failed-precondition",
        "需先完成并发布该官方挑战的故事",
      );
    }

    // 2. 幂等检查：同 (uid, challengeId) 已发放过 → 返回旧记录
    const owned = await db
      .collection("origami")
      .where("ownerId", "==", uid)
      .get();

    const existing = owned.docs.find(
      (d) => d.data().sourceChallengeId === challengeId,
    );
    if (existing) {
      const data = existing.data();
      logger.info(
        `[generateOrigami] idempotent hit uid=${uid} challenge=${challengeId} origami=${existing.id}`,
      );
      return {
        origamiId: existing.id,
        imageUrl: data.imageUrl as string,
        style: data.style as string,
        source: data.source as "pregen" | "flux",
      };
    }

    // 3. 选风格
    const style = pickStyle(requestedStyle, challengeId);

    // 4. 出图
    let imageUrl: string;
    let source: "pregen" | "flux";

    if (live === true) {
      const liveUrl = await tryReplicate(style).catch((err) => {
        logger.warn(
          `[generateOrigami] Replicate failed for style=${style}, falling back to pool`,
          err,
        );
        return null;
      });
      if (liveUrl) {
        imageUrl = liveUrl;
        source = "flux";
      } else {
        imageUrl = await pickFromPool(style);
        source = "pregen";
      }
    } else {
      imageUrl = await pickFromPool(style);
      source = "pregen";
    }

    // 5. 写记录
    const ref = await db.collection("origami").add({
      ownerId: uid,
      imageUrl,
      style,
      sourceChallengeId: challengeId,
      source,
      createdAt: FieldValue.serverTimestamp(),
    });

    logger.info(
      `[generateOrigami] created origami=${ref.id} uid=${uid} style=${style} source=${source}`,
    );

    return { origamiId: ref.id, imageUrl, style, source };
  },
);

/**
 * 风格选择：调用方传 → 直接用；否则按 challengeId 哈希稳定选风格
 * （同挑战多次调用——比如不同测试账号——选同款，便于演示对比）。
 */
function pickStyle(
  requested: string | undefined,
  challengeId: string,
): Style {
  if (requested && (STYLES as readonly string[]).includes(requested)) {
    return requested as Style;
  }
  let hash = 0;
  for (let i = 0; i < challengeId.length; i++) {
    hash = (hash * 31 + challengeId.charCodeAt(i)) | 0;
  }
  return STYLES[Math.abs(hash) % STYLES.length];
}

/**
 * 从 Storage `origami/pool/{style}/` 随机挑一张图。
 *
 * 返回 Firebase Storage 下载 URL（依赖 `storage.rules` 中
 * `match /origami/{file=**}: allow read: if true` 实现免 token 访问）。
 */
async function pickFromPool(style: Style): Promise<string> {
  const bucket = getStorage().bucket();
  const [files] = await bucket.getFiles({
    prefix: `origami/pool/${style}/`,
  });
  const candidates = files.filter(
    (f) => !f.name.endsWith("/") && /\.(png|jpg|jpeg|webp)$/i.test(f.name),
  );
  if (candidates.length === 0) {
    throw new HttpsError(
      "failed-precondition",
      `素材池 origami/pool/${style}/ 为空，请上传至少一张图`,
    );
  }
  const pick = candidates[Math.floor(Math.random() * candidates.length)];
  return firebaseDownloadUrl(bucket.name, pick.name);
}

/**
 * 调 Replicate Flux Schnell 出图，存到 `origami/live/{style}/`，返回 URL。
 * 全程 20s 超时；任何失败抛错，由上层降级。
 */
async function tryReplicate(style: Style): Promise<string> {
  const token = REPLICATE_API_TOKEN.value();
  if (!token) {
    throw new Error("REPLICATE_API_TOKEN secret not set");
  }

  const prompts: Record<Style, string> = {
    zen: "minimal origami crane, cream rice paper background, soft natural lighting, paper texture, top-down studio photo, no text",
    steampunk:
      "steampunk origami mechanical bird with tiny brass gears and copper wires, on aged parchment, dramatic side light, no text",
    ink: "ink wash origami crane in sumi-e style, calligraphy paper background, monochrome black ink, no text",
  };

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 20_000);

  try {
    const createRes = await fetch(
      "https://api.replicate.com/v1/models/black-forest-labs/flux-schnell/predictions",
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${token}`,
          "Content-Type": "application/json",
          // 同步等结果（Flux Schnell 单图 ~1–2s，远低于 60s 同步上限）
          Prefer: "wait",
        },
        body: JSON.stringify({
          input: {
            prompt: prompts[style],
            aspect_ratio: "1:1",
            output_format: "png",
            num_outputs: 1,
          },
        }),
        signal: controller.signal,
      },
    );

    if (!createRes.ok) {
      throw new Error(
        `Replicate API ${createRes.status}: ${await createRes.text()}`,
      );
    }

    const json = (await createRes.json()) as { output?: string | string[] };
    const url = Array.isArray(json.output) ? json.output[0] : json.output;
    if (typeof url !== "string") {
      throw new Error("Replicate returned no image URL");
    }

    const imgRes = await fetch(url, { signal: controller.signal });
    if (!imgRes.ok) {
      throw new Error(`download image failed: ${imgRes.status}`);
    }
    const buf = Buffer.from(await imgRes.arrayBuffer());

    const bucket = getStorage().bucket();
    const objectName = `origami/live/${style}/${Date.now()}-${Math.random()
      .toString(36)
      .slice(2, 10)}.png`;
    await bucket.file(objectName).save(buf, { contentType: "image/png" });

    return firebaseDownloadUrl(bucket.name, objectName);
  } finally {
    clearTimeout(timer);
  }
}

/**
 * Firebase Storage 免 token 下载 URL。
 * 仅当 storage.rules 的对应路径允许 read:true 时该 URL 可公开访问。
 */
function firebaseDownloadUrl(
  bucketName: string,
  objectName: string,
): string {
  return `https://firebasestorage.googleapis.com/v0/b/${bucketName}/o/${encodeURIComponent(
    objectName,
  )}?alt=media`;
}

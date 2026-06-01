import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/v2";
import { defineSecret } from "firebase-functions/params";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";

/**
 * 默认风格枚举（决定 `pickStyleByHash` 落点 + 默认 prompt 字典 key）。
 * `challenges/{id}.style` 字段允许超出此白名单的自由字符串（例如 "autumn"），
 * 用于「per-challenge 自定义图池」场景。这种情况下 Replicate prompt 走通用模板。
 */
const STYLES = ["zen", "steampunk", "ink"] as const;
type DefaultStyle = (typeof STYLES)[number];

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

    // 3. F1：读 challenge 文档拿 imagePool / style 自定义。
    //    优先级：调用方 requestedStyle > challenge.style > pickStyleByHash(challengeId)
    //    池路径：challenge.imagePool > origami/pool/{style}
    const challengeSnap = await db.collection("challenges").doc(challengeId).get();
    const challengeData = challengeSnap.data();
    const challengeStyle = challengeData?.style as string | undefined;
    const customPool = challengeData?.imagePool as string | undefined;

    const style = requestedStyle ?? challengeStyle ?? pickStyleByHash(challengeId);
    const poolPath = customPool ?? `origami/pool/${style}`;

    // 4. 出图
    let imageUrl: string;
    let source: "pregen" | "flux";

    if (live === true) {
      const liveUrl = await tryReplicate(style).catch((err) => {
        logger.warn(
          `[generateOrigami] Replicate failed for style=${style}, falling back to pool=${poolPath}`,
          err,
        );
        return null;
      });
      if (liveUrl) {
        imageUrl = liveUrl;
        source = "flux";
      } else {
        imageUrl = await pickFromFolder(poolPath);
        source = "pregen";
      }
    } else {
      imageUrl = await pickFromFolder(poolPath);
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
 * 风格哈希兜底：当 challenges 既无 `style` 字段、调用方也未 `requestedStyle` 时使用。
 * 按 challengeId 字符串哈希稳定取值，同挑战所有用户拿同一 default style。
 */
function pickStyleByHash(challengeId: string): DefaultStyle {
  let hash = 0;
  for (let i = 0; i < challengeId.length; i++) {
    hash = (hash * 31 + challengeId.charCodeAt(i)) | 0;
  }
  return STYLES[Math.abs(hash) % STYLES.length];
}

/**
 * 从 Storage 任意 prefix 随机挑一张图。
 *
 * F1 后用 `challenge.imagePool` 覆盖默认 `origami/pool/{style}`，所以这个函数
 * 接受任意 prefix；非空白名单扩展名（png/jpg/webp）过滤。
 *
 * 返回 Firebase Storage 下载 URL（依赖 `storage.rules` 中
 * `match /origami/{file=**}: allow read: if true` 实现免 token 访问）。
 */
async function pickFromFolder(prefix: string): Promise<string> {
  const normPrefix = prefix.endsWith("/") ? prefix : `${prefix}/`;
  const bucket = getStorage().bucket();
  const [files] = await bucket.getFiles({ prefix: normPrefix });
  const candidates = files.filter(
    (f) => !f.name.endsWith("/") && /\.(png|jpg|jpeg|webp)$/i.test(f.name),
  );
  if (candidates.length === 0) {
    throw new HttpsError(
      "failed-precondition",
      `素材池 ${normPrefix} 为空，请上传至少一张图`,
    );
  }
  const pick = candidates[Math.floor(Math.random() * candidates.length)];
  return firebaseDownloadUrl(bucket.name, pick.name);
}

/** style + 用户 3 词 → 完整 prompt。F2 自由 AI 调用方用。 */
export function buildPromptWithWords(
  style: string,
  words: string[],
): string {
  const styleDescriptors: Record<DefaultStyle, string> = {
    zen: "Japanese zen aesthetic with cream rice paper background and soft natural lighting",
    steampunk:
      "steampunk aesthetic with brass gears and copper accents on aged parchment background",
    ink: "ink wash sumi-e style on calligraphy paper, monochrome black ink",
  };
  const descriptor =
    styleDescriptors[style as DefaultStyle] ?? `${style} aesthetic`;
  const joined = words.map((w) => w.trim()).filter((w) => w).join(", ");
  return `single origami paper craft, ${descriptor}, expressing themes of ${joined}, paper texture, top-down studio photo, no text`;
}

/**
 * 内部：把一个完整 prompt 提交给 Replicate Flux Schnell 出图，
 * 存到 `origami/live/{style}/`，返回 URL。全程 20s 超时，任何失败抛错。
 */
async function runReplicate(
  prompt: string,
  style: string,
): Promise<string> {
  const token = REPLICATE_API_TOKEN.value();
  if (!token) {
    throw new Error("REPLICATE_API_TOKEN secret not set");
  }

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
            prompt,
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
 * 官方挑战路径专用：从默认 prompt 字典选 → runReplicate。
 * （T1.8b live=true 路径仍用此入口。）
 */
export async function tryReplicate(style: string): Promise<string> {
  const defaultPrompts: Record<DefaultStyle, string> = {
    zen: "minimal origami crane, cream rice paper background, soft natural lighting, paper texture, top-down studio photo, no text",
    steampunk:
      "steampunk origami mechanical bird with tiny brass gears and copper wires, on aged parchment, dramatic side light, no text",
    ink: "ink wash origami crane in sumi-e style, calligraphy paper background, monochrome black ink, no text",
  };
  const prompt =
    defaultPrompts[style as DefaultStyle] ??
    `single origami paper craft, ${style} theme, paper texture, top-down studio photo, neutral background, no text`;
  return runReplicate(prompt, style);
}

/** F2 自由 AI 入口：style + 3 个用户关键词 → runReplicate。 */
export async function tryReplicateWithWords(
  style: string,
  words: string[],
): Promise<string> {
  return runReplicate(buildPromptWithWords(style, words), style);
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

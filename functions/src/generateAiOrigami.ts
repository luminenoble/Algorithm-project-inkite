import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/v2";
import { defineSecret } from "firebase-functions/params";
import { getFirestore, FieldValue } from "firebase-admin/firestore";

import { tryReplicateWithWords } from "./generateOrigami";
import { consumeAiQuota, refundAiQuota } from "./aiQuota";

const REPLICATE_API_TOKEN = defineSecret("REPLICATE_API_TOKEN");

/** 默认随机 style 池——与 generateOrigami 的 STYLES 对齐。 */
const STYLES = ["zen", "steampunk", "ink"] as const;

/** 单词长度上限：避免恶意超长 prompt 注入。 */
const MAX_WORD_LENGTH = 16;

interface AiGenerateRequest {
  /** 必填：用户自定义的 3 个关键词，长度恰为 3。 */
  words: string[];
  style?: string;
  __testUid?: string;
}

interface AiGenerateResponse {
  origamiId: string;
  imageUrl: string;
  style: string;
  words: string[];
  source: "flux";
  quota: {
    used: number;
    limit: number;
    windowExpiresAtMs: number;
    bonusLikes: boolean;
    bonusChallenges: boolean;
  };
}

/**
 * F2 — 自由 AI 折纸 Callable（与 `generateOrigami` 完全分开）。
 *
 * 与官方挑战发放路径的差异：
 * - 无 challengeId / 无防刷查询：用户主动调用，不绑挑战
 * - 强制走 Replicate（**无降级回池**）—— 自由 AI 的价值就是 AI，回池就背离了产品意图
 * - 周配额：base 3 + bonus（likes>20 +1，5 篇官方 +1），最大 5
 * - 滚动 7 天窗口（从用户本周首次调用起算），到期自动重置
 * - 失败时退回 1 次配额，允许用户重试
 * - 写入 `origami/{id}` 的 `sourceChallengeId: null`、`source: 'flux'`
 *
 * 鉴权：同 generateOrigami，emulator 走 `__testUid`，prod 必须 `request.auth`。
 */
export const generateAiOrigami = onCall<AiGenerateRequest>(
  { secrets: [REPLICATE_API_TOKEN] },
  async (request): Promise<AiGenerateResponse> => {
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

    // 0. 验证 3 个关键词
    const rawWords = request.data.words;
    if (!Array.isArray(rawWords) || rawWords.length !== 3) {
      throw new HttpsError(
        "invalid-argument",
        "需要正好 3 个关键词",
      );
    }
    const words = rawWords.map((w) =>
      typeof w === "string" ? w.trim() : "",
    );
    if (words.some((w) => w.length === 0)) {
      throw new HttpsError("invalid-argument", "关键词不能为空");
    }
    if (words.some((w) => w.length > MAX_WORD_LENGTH)) {
      throw new HttpsError(
        "invalid-argument",
        `单个关键词不能超过 ${MAX_WORD_LENGTH} 字`,
      );
    }

    // 1. 配额检查 + 占用（事务内原子化）
    const result = await consumeAiQuota(uid);
    if (!result.ok) {
      const expires = new Date(result.snapshot.windowExpiresAtMs);
      throw new HttpsError(
        "resource-exhausted",
        `本周 AI 折纸配额已用完 (${result.snapshot.used}/${result.snapshot.limit})。${expires.toLocaleDateString("zh-CN")} 重置。`,
      );
    }
    const snapshot = result.snapshot;

    // 2. 选 style（调用方传 → 用；否则三种默认风格随机）
    const requestedStyle = request.data.style;
    const style =
      requestedStyle ?? STYLES[Math.floor(Math.random() * STYLES.length)];

    // 3. Replicate 实拍（**无 fallback**——失败退回配额）
    let imageUrl: string;
    try {
      imageUrl = await tryReplicateWithWords(style, words);
    } catch (e) {
      await refundAiQuota(uid);
      logger.error(
        `[generateAiOrigami] Replicate failed uid=${uid} style=${style} words=${words.join("/")}`,
        e,
      );
      throw new HttpsError(
        "internal",
        "AI 生成失败，配额已退回，请稍后重试",
      );
    }

    // 4. 写记录（带 words，给后续查看 / 复述）
    const db = getFirestore();
    const ref = await db.collection("origami").add({
      ownerId: uid,
      imageUrl,
      style,
      words,
      sourceChallengeId: null,
      source: "flux",
      createdAt: FieldValue.serverTimestamp(),
    });

    logger.info(
      `[generateAiOrigami] uid=${uid} style=${style} words=${words.join("/")} origami=${ref.id} quota=${snapshot.used}/${snapshot.limit}`,
    );

    return {
      origamiId: ref.id,
      imageUrl,
      style,
      words,
      source: "flux",
      quota: {
        used: snapshot.used,
        limit: snapshot.limit,
        windowExpiresAtMs: snapshot.windowExpiresAtMs,
        bonusLikes: snapshot.bonusLikes,
        bonusChallenges: snapshot.bonusChallenges,
      },
    };
  },
);

import {
  getFirestore,
  Timestamp,
} from "firebase-admin/firestore";
import { logger } from "firebase-functions/v2";

/** 基础周配额。bonus 在 userStats.ts 中由触发器自动翻 true 后 +1。 */
export const BASE_WEEKLY_QUOTA = 3;

/** likesReceived 跨过此值时永久 +1 quota。 */
export const BONUS_LIKES_THRESHOLD = 20;

/** officialChallengesCount 跨过此值时永久 +1 quota。 */
export const BONUS_CHALLENGES_THRESHOLD = 5;

/** 滚动窗口长度（ms）。从用户本周首次调用起算 7 天。 */
const WEEK_MS = 7 * 24 * 60 * 60 * 1000;

export interface QuotaSnapshot {
  used: number;
  limit: number;
  weekStartAtMs: number;
  windowExpiresAtMs: number;
  bonusLikes: boolean;
  bonusChallenges: boolean;
}

type ConsumeResult =
  | { ok: true; snapshot: QuotaSnapshot }
  | { ok: false; snapshot: QuotaSnapshot };

/**
 * 配额事务：检查 + 占用。
 *
 * 1. 若 `aiUsage.weekStartAt` 不存在或已过 7 天 → 重置 count=0、weekStartAt=now
 * 2. 算 limit = base + (bonusLikes?1:0) + (bonusChallenges?1:0)
 *    （bonus flag 由 userStats.applyUserDelta 在阈值跨越时设置）
 * 3. 若 count >= limit → 返回 `{ ok: false, snapshot }`，不写库
 * 4. 否则 count += 1，写回，返回 `{ ok: true }`
 *
 * 调用方拿到 `ok: false` 时应抛 `resource-exhausted` 给客户端。
 */
export async function consumeAiQuota(uid: string): Promise<ConsumeResult> {
  const db = getFirestore();
  const userRef = db.collection("users").doc(uid);

  return await db.runTransaction(async (tx) => {
    const snap = await tx.get(userRef);
    if (!snap.exists) {
      throw new Error(`user profile missing: ${uid}`);
    }
    const data = snap.data() ?? {};
    const aiUsage =
      (data.aiUsage as Record<string, unknown> | undefined) ?? {};

    const now = Date.now();
    const lastStartMs =
      aiUsage.weekStartAt instanceof Timestamp
        ? aiUsage.weekStartAt.toMillis()
        : 0;

    const isNewWindow = lastStartMs === 0 || now - lastStartMs >= WEEK_MS;
    const effectiveStart = isNewWindow ? now : lastStartMs;
    const currentUsed = isNewWindow
      ? 0
      : ((aiUsage.count as number | undefined) ?? 0);

    const bonusLikes = (aiUsage.bonusLikes as boolean | undefined) === true;
    const bonusChallenges =
      (aiUsage.bonusChallenges as boolean | undefined) === true;
    const limit =
      BASE_WEEKLY_QUOTA + (bonusLikes ? 1 : 0) + (bonusChallenges ? 1 : 0);

    const snapshot: QuotaSnapshot = {
      used: currentUsed,
      limit,
      weekStartAtMs: effectiveStart,
      windowExpiresAtMs: effectiveStart + WEEK_MS,
      bonusLikes,
      bonusChallenges,
    };

    if (currentUsed >= limit) {
      return { ok: false, snapshot };
    }

    const newUsed = currentUsed + 1;
    tx.update(userRef, {
      "aiUsage.weekStartAt": Timestamp.fromMillis(effectiveStart),
      "aiUsage.count": newUsed,
    });

    return {
      ok: true,
      snapshot: { ...snapshot, used: newUsed },
    };
  });
}

/**
 * Replicate 调用失败时退回配额。
 * 仅在 consumeAiQuota 已 ok:true 时调用。同事务读改写保证幂等。
 */
export async function refundAiQuota(uid: string): Promise<void> {
  const db = getFirestore();
  const userRef = db.collection("users").doc(uid);
  try {
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(userRef);
      if (!snap.exists) return;
      const data = snap.data() ?? {};
      const aiUsage =
        (data.aiUsage as Record<string, unknown> | undefined) ?? {};
      const used = (aiUsage.count as number | undefined) ?? 0;
      if (used <= 0) return;
      tx.update(userRef, { "aiUsage.count": used - 1 });
    });
    logger.info(`[aiQuota] refunded uid=${uid}`);
  } catch (e) {
    logger.error(`[aiQuota] refund failed uid=${uid}`, e);
  }
}

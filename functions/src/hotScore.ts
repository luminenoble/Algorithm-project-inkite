import { getFirestore, Timestamp } from "firebase-admin/firestore";
import { logger } from "firebase-functions/v2";

/**
 * hotScore 公式：`likeCount * 2 + commentCount + freshness * 5`
 *
 * freshness 在发布后 72 小时内线性衰减至 0；新发空 story 起步 `5`，
 * 让新内容有一个"自然上浮再被埋"的窗口。
 *
 * 下游若想调权重 / 衰减窗口，只改本函数；触发器与 Callable 都不需要碰。
 */
export function computeHotScore(args: {
  likeCount: number;
  commentCount: number;
  createdAt: Date | null;
  now: Date;
}): number {
  const { likeCount, commentCount, createdAt, now } = args;
  const ageHours = createdAt
    ? Math.max(0, (now.getTime() - createdAt.getTime()) / 3_600_000)
    : 0;
  const freshness = Math.max(0, 1 - ageHours / 72);
  return likeCount * 2 + commentCount + freshness * 5;
}

/**
 * 共享事务：根据传入的 like / comment delta 增减父 story 的计数，
 * 并同步重算 hotScore。`Math.max(0, ...)` 防御计数跑负（极端时序保护）。
 */
export async function applyDeltaAndRecompute(args: {
  storyId: string;
  likeDelta?: number;
  commentDelta?: number;
}): Promise<void> {
  const { storyId, likeDelta = 0, commentDelta = 0 } = args;
  const db = getFirestore();
  const ref = db.collection("stories").doc(storyId);

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) {
      logger.warn(`story ${storyId} missing; skip counter update`);
      return;
    }
    const data = snap.data() ?? {};
    const newLikeCount = Math.max(
      0,
      (typeof data.likeCount === "number" ? data.likeCount : 0) + likeDelta,
    );
    const newCommentCount = Math.max(
      0,
      (typeof data.commentCount === "number" ? data.commentCount : 0) +
        commentDelta,
    );
    const createdAt =
      data.createdAt instanceof Timestamp ? data.createdAt.toDate() : null;
    const hotScore = computeHotScore({
      likeCount: newLikeCount,
      commentCount: newCommentCount,
      createdAt,
      now: new Date(),
    });
    tx.update(ref, {
      likeCount: newLikeCount,
      commentCount: newCommentCount,
      hotScore,
    });
  });
}

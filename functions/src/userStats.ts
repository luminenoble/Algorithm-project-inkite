import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { logger } from "firebase-functions/v2";

/**
 * 互动分阈值：≥ 此值时自动解锁 `unlocks.magicInk`。
 * 公式 `engagementScore = storiesCount*3 + likesReceived`，所以：
 *   - 2 篇已发布故事 = 6 → 触发
 *   - 1 篇已发布 + 2 个被赞 = 5 → 触发
 * Demo 体量下容易达到，又不是「白嫖」。
 */
const MAGIC_INK_THRESHOLD = 5;

/**
 * 房间 ID：与客户端 `ZenGardenScreen.roomId` 对齐。
 * 完成首篇 official + published story 时 push 进 `unlocks.rooms`。
 */
export const ZEN_GARDEN_ROOM_ID = "zen_garden";

/**
 * 维护 `users/{uid}.stats.*` + `unlocks.*` 的统一入口。
 *
 * - `storiesDelta` / `likesDelta` 用事务读改回写，`Math.max(0, …)` 防负
 * - `engagementScore` 同步重算
 * - 跨阈值时**只 flip 一次** `unlocks.magicInk = true`（不再 toggle）
 * - `unlockRoom` 用 `FieldValue.arrayUnion`，幂等
 *
 * 任何失败仅记 error 日志，不抛——上层触发器会重试，避免脏数据卡链路。
 */
export async function applyUserDelta(
  uid: string,
  opts: {
    storiesDelta?: number;
    likesDelta?: number;
    unlockRoom?: string;
  },
): Promise<void> {
  if (!uid) return;
  const { storiesDelta = 0, likesDelta = 0, unlockRoom } = opts;
  if (storiesDelta === 0 && likesDelta === 0 && !unlockRoom) return;

  const db = getFirestore();
  const userRef = db.collection("users").doc(uid);

  try {
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(userRef);
      if (!snap.exists) {
        logger.warn(`[userStats] user ${uid} missing; skip delta`, opts);
        return;
      }
      const data = snap.data() ?? {};
      const stats = (data.stats as Record<string, number> | undefined) ?? {};
      const unlocks =
        (data.unlocks as { magicInk?: boolean; rooms?: string[] } | undefined) ??
        {};

      const newStoriesCount = Math.max(
        0,
        (stats.storiesCount ?? 0) + storiesDelta,
      );
      const newLikesReceived = Math.max(
        0,
        (stats.likesReceived ?? 0) + likesDelta,
      );
      const newEngagement = newStoriesCount * 3 + newLikesReceived;

      const update: Record<string, unknown> = {
        "stats.storiesCount": newStoriesCount,
        "stats.likesReceived": newLikesReceived,
        "stats.engagementScore": newEngagement,
      };

      if (newEngagement >= MAGIC_INK_THRESHOLD && !unlocks.magicInk) {
        update["unlocks.magicInk"] = true;
        logger.info(
          `[userStats] magicInk unlocked uid=${uid} engagement=${newEngagement}`,
        );
      }

      if (unlockRoom) {
        update["unlocks.rooms"] = FieldValue.arrayUnion(unlockRoom);
      }

      tx.update(userRef, update);
    });
  } catch (e) {
    logger.error(`[userStats] applyUserDelta failed uid=${uid}`, opts, e);
  }
}

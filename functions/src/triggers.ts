import {
  onDocumentCreated,
  onDocumentDeleted,
  onDocumentUpdated,
} from "firebase-functions/v2/firestore";
import { Timestamp, getFirestore } from "firebase-admin/firestore";
import { logger } from "firebase-functions/v2";

import { applyDeltaAndRecompute, computeHotScore } from "./hotScore";
import { applyUserDelta, ZEN_GARDEN_ROOM_ID } from "./userStats";

/**
 * 新 story 落库时初始化三个 CF-only 字段。
 *
 * 关键：T1.6 `Story.toCreateMap` 故意不写 likeCount/commentCount/hotScore，
 * Firestore 的 `orderBy('hotScore', desc)` 会自动排除字段缺失的文档——
 * 不补这一步，新 story 永远不会进排行榜，直到首次互动。
 *
 * T1.8c 追加：如果创建时已直接发布到广场，给作者 stats.storiesCount +1；
 * 官方挑战首发顺手 push 禅意花园房间 ID（arrayUnion 幂等）。
 */
export const onStoryCreated = onDocumentCreated(
  "stories/{storyId}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const data = snap.data();
    const createdAt =
      data.createdAt instanceof Timestamp ? data.createdAt.toDate() : null;
    const hotScore = computeHotScore({
      likeCount: 0,
      commentCount: 0,
      createdAt,
      now: new Date(),
    });
    await snap.ref.update({
      likeCount: 0,
      commentCount: 0,
      hotScore,
    });

    if (data.publishedToSquare === true) {
      const isOfficial = data.mode === "official";
      await applyUserDelta(data.authorId as string, {
        storiesDelta: 1,
        officialDelta: isOfficial ? 1 : 0,
        unlockRoom: isOfficial ? ZEN_GARDEN_ROOM_ID : undefined,
      });
    }
  },
);

/**
 * T1.8c：监控 `publishedToSquare` 的翻转。
 *
 * 草稿 → 已发布：stats.storiesCount +1；首次发官方挑战时 push 禅意花园房间 ID。
 * 已发布 → 撤回：stats.storiesCount -1。**已解锁的 room 不撤回**（schema 决定）。
 * 字段无关变更（标题 / 正文）忽略，零写入。
 */
export const onStoryUpdated = onDocumentUpdated(
  "stories/{storyId}",
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;

    const wasPublished = before.publishedToSquare === true;
    const isPublished = after.publishedToSquare === true;
    if (wasPublished === isPublished) return;

    const authorId = after.authorId as string;
    if (!authorId) return;

    if (!wasPublished && isPublished) {
      const isOfficial = after.mode === "official";
      await applyUserDelta(authorId, {
        storiesDelta: 1,
        officialDelta: isOfficial ? 1 : 0,
        unlockRoom: isOfficial ? ZEN_GARDEN_ROOM_ID : undefined,
      });
    } else {
      // 撤回：stories -1；如果原是 official，official 也 -1。已解锁的 room / bonus 不撤回。
      const wasOfficial = before.mode === "official";
      await applyUserDelta(authorId, {
        storiesDelta: -1,
        officialDelta: wasOfficial ? -1 : 0,
      });
    }
  },
);

/**
 * T1.8c：发布过的 story 被删 → stats.storiesCount -1（保持账面一致）。
 */
export const onStoryDeleted = onDocumentDeleted(
  "stories/{storyId}",
  async (event) => {
    const data = event.data?.data();
    if (!data) return;
    if (data.publishedToSquare === true && data.authorId) {
      const isOfficial = data.mode === "official";
      await applyUserDelta(data.authorId as string, {
        storiesDelta: -1,
        officialDelta: isOfficial ? -1 : 0,
      });
    }
  },
);

export const onLikeCreated = onDocumentCreated(
  "stories/{storyId}/likes/{uid}",
  async (event) => {
    const storyId = event.params.storyId;
    const likerUid = event.params.uid;
    await applyDeltaAndRecompute({ storyId, likeDelta: 1 });

    // T1.8c：给被赞 story 的作者 likesReceived +1（防自赞守护）。
    await updateAuthorLikes(storyId, likerUid, 1);
  },
);

export const onLikeDeleted = onDocumentDeleted(
  "stories/{storyId}/likes/{uid}",
  async (event) => {
    const storyId = event.params.storyId;
    const likerUid = event.params.uid;
    await applyDeltaAndRecompute({ storyId, likeDelta: -1 });

    await updateAuthorLikes(storyId, likerUid, -1);
  },
);

export const onCommentCreated = onDocumentCreated(
  "stories/{storyId}/comments/{commentId}",
  async (event) => {
    await applyDeltaAndRecompute({
      storyId: event.params.storyId,
      commentDelta: 1,
    });
  },
);

export const onCommentDeleted = onDocumentDeleted(
  "stories/{storyId}/comments/{commentId}",
  async (event) => {
    await applyDeltaAndRecompute({
      storyId: event.params.storyId,
      commentDelta: -1,
    });
  },
);

/**
 * 查 story 的 authorId 给作者改 likesReceived。
 * 自赞场景（理论上 T1.4 规则拒）做防御性 skip。
 */
async function updateAuthorLikes(
  storyId: string,
  likerUid: string,
  delta: number,
): Promise<void> {
  const db = getFirestore();
  const snap = await db.collection("stories").doc(storyId).get();
  const authorId = snap.data()?.authorId as string | undefined;
  if (!authorId) {
    logger.warn(`[T1.8c] like on missing story ${storyId}`);
    return;
  }
  if (authorId === likerUid) {
    logger.warn(`[T1.8c] self-like detected story=${storyId} uid=${likerUid}`);
    return;
  }
  await applyUserDelta(authorId, { likesDelta: delta });
}

import {
  onDocumentCreated,
  onDocumentDeleted,
} from "firebase-functions/v2/firestore";
import { Timestamp } from "firebase-admin/firestore";

import { applyDeltaAndRecompute, computeHotScore } from "./hotScore";

/**
 * 新 story 落库时初始化三个 CF-only 字段。
 *
 * 关键：T1.6 `Story.toCreateMap` 故意不写 likeCount/commentCount/hotScore，
 * Firestore 的 `orderBy('hotScore', desc)` 会自动排除字段缺失的文档——
 * 不补这一步，新 story 永远不会进排行榜，直到首次互动。
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
  },
);

export const onLikeCreated = onDocumentCreated(
  "stories/{storyId}/likes/{uid}",
  async (event) => {
    await applyDeltaAndRecompute({
      storyId: event.params.storyId,
      likeDelta: 1,
    });
  },
);

export const onLikeDeleted = onDocumentDeleted(
  "stories/{storyId}/likes/{uid}",
  async (event) => {
    await applyDeltaAndRecompute({
      storyId: event.params.storyId,
      likeDelta: -1,
    });
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

import { initializeApp } from "firebase-admin/app";
import { setGlobalOptions } from "firebase-functions/v2";

initializeApp();

// 与 Firestore / Storage 同区；maxInstances 兜底防被刷出账单。
setGlobalOptions({
  region: "asia-east1",
  maxInstances: 5,
});

export {
  onStoryCreated,
  onLikeCreated,
  onLikeDeleted,
  onCommentCreated,
  onCommentDeleted,
} from "./triggers";

export { recomputeHotScores } from "./recompute";

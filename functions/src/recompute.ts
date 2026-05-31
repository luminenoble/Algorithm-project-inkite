import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/v2";
import { getFirestore, Timestamp } from "firebase-admin/firestore";

import { computeHotScore } from "./hotScore";

const BATCH_SIZE = 400;

/**
 * 手动重算全表 hotScore。演示前调一次刷榜，把所有种子 story 的 freshness
 * 拉到当下时间。
 *
 * 鉴权策略：
 * - 生产：登录用户即可调（dev 期）；T1.10 收紧时换成 admin claim 校验
 * - Emulator：跳过 auth 校验（emulator 的 Auth 不签发真实 ID Token，
 *   functions:shell 与 HTTP 直调都拿不到 request.auth，跳过以便本地验证）
 *
 * 返回：`{ recomputed: number }`
 */
export const recomputeHotScores = onCall(async (request) => {
  const isEmulator = process.env.FUNCTIONS_EMULATOR === "true";
  if (!isEmulator && !request.auth) {
    throw new HttpsError("unauthenticated", "需要登录才能调用 recomputeHotScores");
  }

  const db = getFirestore();
  const snap = await db.collection("stories").get();
  const now = new Date();
  let total = 0;

  for (let i = 0; i < snap.docs.length; i += BATCH_SIZE) {
    const batch = db.batch();
    const chunk = snap.docs.slice(i, i + BATCH_SIZE);
    for (const doc of chunk) {
      const data = doc.data();
      const createdAt =
        data.createdAt instanceof Timestamp ? data.createdAt.toDate() : null;
      const hotScore = computeHotScore({
        likeCount: typeof data.likeCount === "number" ? data.likeCount : 0,
        commentCount:
          typeof data.commentCount === "number" ? data.commentCount : 0,
        createdAt,
        now,
      });
      batch.update(doc.ref, { hotScore });
    }
    await batch.commit();
    total += chunk.length;
  }

  logger.info(`recomputed hotScore for ${total} stories`);
  return { recomputed: total };
});

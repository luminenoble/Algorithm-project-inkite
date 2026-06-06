import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/v2";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import { firebaseDownloadUrl } from "./storageUrl";

/**
 * T6.0：故事书封面上传 Callable（`docs/next-design-detailed.md` §2）。
 *
 * 唯一的后端增量。守 `CLAUDE.md` §7「客户端不直连 Storage」：客户端把图片
 * base64 传上来，由 CF 用 Admin SDK 写 Storage 并回写 `storybooks.coverUrl`，
 * 与折纸图（`generateOrigami`）同款落图模式。
 */

interface UploadRequest {
  storybookId: string;
  imageBase64: string;
  contentType?: string;
  /** Emulator 模式下手动传入测试 uid（对齐 generateOrigami.ts 的同名约定）。 */
  __testUid?: string;
}

interface UploadResponse {
  coverUrl: string;
}

/** 封面大小上限：1 MB。 */
const MAX_COVER_BYTES = 1024 * 1024;

export const uploadStorybookCover = onCall<UploadRequest>(
  async (request): Promise<UploadResponse> => {
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

    const { storybookId, imageBase64, contentType } = request.data;
    if (!storybookId || typeof storybookId !== "string") {
      throw new HttpsError("invalid-argument", "缺少 storybookId");
    }
    if (!imageBase64 || typeof imageBase64 !== "string") {
      throw new HttpsError("invalid-argument", "缺少 imageBase64");
    }

    const db = getFirestore();
    const ref = db.collection("storybooks").doc(storybookId);
    const snap = await ref.get();
    if (!snap.exists) {
      throw new HttpsError("not-found", "故事书不存在");
    }
    // 归属校验：只能给自己的故事书换封面。
    if (snap.data()?.ownerId !== uid) {
      throw new HttpsError("permission-denied", "只能给自己的故事书换封面");
    }

    const buf = Buffer.from(imageBase64, "base64");
    if (buf.length === 0) {
      throw new HttpsError("invalid-argument", "封面图为空");
    }
    if (buf.length > MAX_COVER_BYTES) {
      throw new HttpsError("invalid-argument", "封面图过大（≤1MB）");
    }

    const type =
      typeof contentType === "string" && contentType.length > 0
        ? contentType
        : "image/png";

    // 覆盖写：同书换封面直接覆盖，URL 不变省去清理（§2.1）。
    const bucket = getStorage().bucket();
    const objectName = `storybook-covers/${uid}/${storybookId}.png`;
    await bucket.file(objectName).save(buf, { contentType: type });

    const coverUrl = firebaseDownloadUrl(bucket.name, objectName);

    // 回写 Firestore：上传成功即清空 coverAssetId 让 coverUrl 生效（§2.1）。
    await ref.update({
      coverUrl,
      coverAssetId: null,
      updatedAt: FieldValue.serverTimestamp(),
    });

    logger.info(
      `[uploadStorybookCover] uid=${uid} storybook=${storybookId} bytes=${buf.length}`,
    );

    return { coverUrl };
  },
);

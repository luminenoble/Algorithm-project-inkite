/**
 * Firebase Storage 免 token 下载 URL。
 *
 * 仅当 `storage.rules` 的对应路径允许 `read: true` 时该 URL 可公开访问
 * （`origami/**` 与 `storybook-covers/**` 均为 read:true）。
 *
 * 抽成共享 helper 供 `generateOrigami.ts`（折纸落图）与
 * `uploadStorybookCover.ts`（故事书封面落图）复用，勿重复实现。
 */
export function firebaseDownloadUrl(
  bucketName: string,
  objectName: string,
): string {
  return `https://firebasestorage.googleapis.com/v0/b/${bucketName}/o/${encodeURIComponent(
    objectName,
  )}?alt=media`;
}

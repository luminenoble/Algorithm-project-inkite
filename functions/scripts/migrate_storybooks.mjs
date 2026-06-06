// T6.5 旧数据迁移脚本：为存量用户建默认故事书，回填存量 story 的
// storybookId / chapterName（`docs/next-design-detailed.md` §5.3）。
//
// 幂等：重复跑不重复建默认书、不覆盖已有归属。
//
// 凭证优先级（与 seed_challenge.mjs 同口径，三选一自动查找）：
//   1. --creds <path>
//   2. GOOGLE_APPLICATION_CREDENTIALS 环境变量
//   3. 当前目录（functions/）下自动查找 *adminsdk*.json
//
// 跑法（在 functions/ 下）：
//   node scripts/migrate_storybooks.mjs --dry-run            # 仅报告，不写
//   node scripts/migrate_storybooks.mjs                      # 实跑
//   node scripts/migrate_storybooks.mjs --proxy http://127.0.0.1:7890

import { readdirSync } from "node:fs";
import { resolve } from "node:path";
import { initializeApp, cert } from "firebase-admin/app";
import { getFirestore, FieldValue } from "firebase-admin/firestore";

const DEFAULT_CHAPTER = "未分章";
const DEFAULT_TITLE = "未分类";

// ─── CLI ──────────────────────────────────────────────────────────────────────

function parseArgs(argv) {
  const result = {};
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg.startsWith("--")) {
      const key = arg.slice(2);
      const next = argv[i + 1];
      if (!next || next.startsWith("--")) {
        result[key] = true;
      } else {
        result[key] = next;
        i++;
      }
    }
  }
  return result;
}

const args = parseArgs(process.argv.slice(2));
const dryRun = Boolean(args["dry-run"]);

// ─── 代理 ────────────────────────────────────────────────────────────────────

const proxy =
  args["proxy"] ||
  process.env.grpc_proxy ||
  process.env.https_proxy ||
  process.env.HTTPS_PROXY;
if (proxy) {
  process.env.grpc_proxy = proxy;
  process.env.https_proxy = proxy;
  console.log(`  (使用代理: ${proxy})`);
}

// ─── 凭证 ────────────────────────────────────────────────────────────────────

function resolveCredPath() {
  if (args["creds"]) return resolve(args["creds"]);
  if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    return process.env.GOOGLE_APPLICATION_CREDENTIALS;
  }
  try {
    const found = readdirSync(process.cwd()).find(
      (f) => f.includes("adminsdk") && f.endsWith(".json"),
    );
    if (found) {
      console.log(`  (自动检测到凭证文件: ${found})`);
      return resolve(process.cwd(), found);
    }
  } catch {}
  return null;
}

const credPath = resolveCredPath();
if (!credPath) {
  console.error(
    "✗ 未找到凭证文件。请用 --creds <path> 指定，或将 adminsdk JSON 放在 functions/ 目录下。",
  );
  process.exit(1);
}

const app = initializeApp({
  credential: cert(credPath),
  projectId: "inkite-demo",
});
const db = getFirestore(app);

const defaultStorybookId = (uid) => `default_${uid}`;

console.log(`\n── T6 故事书迁移${dryRun ? "（DRY-RUN，不写库）" : ""} ──\n`);

// ─── 1. 收集所有 uid（users + stories.authorId）────────────────────────────────

const uids = new Set();

const usersSnap = await db.collection("users").get();
usersSnap.docs.forEach((d) => uids.add(d.id));
console.log(`users 集合: ${usersSnap.size} 个用户`);

const storiesSnap = await db.collection("stories").get();
storiesSnap.docs.forEach((d) => {
  const authorId = d.data().authorId;
  if (typeof authorId === "string" && authorId) uids.add(authorId);
});
console.log(`stories 集合: ${storiesSnap.size} 篇故事`);
console.log(`合计需保证默认书的用户: ${uids.size}\n`);

// ─── 2. 为每个 uid 惰性建默认书（确定性 ID，幂等）──────────────────────────────

let booksCreated = 0;
let booksExisting = 0;
for (const uid of uids) {
  const ref = db.collection("storybooks").doc(defaultStorybookId(uid));
  const snap = await ref.get();
  if (snap.exists) {
    booksExisting++;
    continue;
  }
  booksCreated++;
  if (!dryRun) {
    await ref.set({
      ownerId: uid,
      title: DEFAULT_TITLE,
      chapterOrder: [DEFAULT_CHAPTER],
      isDefault: true,
      pinned: false,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
  }
}
console.log(`默认书: 新建 ${booksCreated}，已存在 ${booksExisting}`);

// ─── 3. 回填存量 story 的 storybookId / chapterName（不覆盖已有）─────────────────

let storiesPatched = 0;
let storiesSkipped = 0;
let batch = db.batch();
let pending = 0;

async function flush() {
  if (pending === 0) return;
  if (!dryRun) await batch.commit();
  batch = db.batch();
  pending = 0;
}

for (const doc of storiesSnap.docs) {
  const data = doc.data();
  const patch = {};
  const authorId = data.authorId;
  const hasBook =
    typeof data.storybookId === "string" && data.storybookId.length > 0;
  const hasChapter =
    typeof data.chapterName === "string" && data.chapterName.length > 0;

  if (!hasBook) {
    if (typeof authorId !== "string" || !authorId) {
      // 无作者的脏数据：跳过，避免造出 default_undefined。
      storiesSkipped++;
      continue;
    }
    patch.storybookId = defaultStorybookId(authorId);
  }
  if (!hasChapter) {
    patch.chapterName = DEFAULT_CHAPTER;
  }

  if (Object.keys(patch).length === 0) {
    storiesSkipped++;
    continue;
  }
  patch.updatedAt = FieldValue.serverTimestamp();
  storiesPatched++;
  if (!dryRun) {
    batch.update(doc.ref, patch);
    pending++;
    // Firestore 批量上限 500，留余量按 400 提交。
    if (pending >= 400) await flush();
  }
}
await flush();

console.log(`story 回填: 补字段 ${storiesPatched}，已合法/跳过 ${storiesSkipped}`);
console.log(
  `\n✓ 迁移${dryRun ? "（DRY-RUN）" : ""}完成。所有存量 story 现应有合法 storybookId / chapterName。\n`,
);
process.exit(0);

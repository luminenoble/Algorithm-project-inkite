// 官方挑战种子脚本：停用旧活跃挑战，写入新挑战。
//
// 凭证优先级（三选一，脚本自动按顺序查找）：
//   1. --creds <path>  直接传路径，最简单
//   2. GOOGLE_APPLICATION_CREDENTIALS 环境变量
//   3. 当前目录（functions/）下自动查找 *adminsdk*.json
//
// 跑法（在 functions/ 下）：
//   node scripts/seed_challenge.mjs --title "秋·霜·归" --words 秋,霜,归
//   node scripts/seed_challenge.mjs --title "灯·雨·归" --words 灯,雨,归 --days 14
//   node scripts/seed_challenge.mjs --title "测试" --words a,b,c --id test-challenge-01
//   node scripts/seed_challenge.mjs --title "未来挑战" --words 星,海,远 --start 2026-06-10T00:00:00+08:00
//   node scripts/seed_challenge.mjs --deactivate-only          # 仅停用，不创建新挑战
//
// 国内网络直连 Google 会 ETIMEDOUT，需挂代理（端口换成你自己的）：
//   node scripts/seed_challenge.mjs --proxy http://127.0.0.1:7890 --title "秋·霜·归" --words 秋,霜,归

import { readdirSync } from "node:fs";
import { resolve } from "node:path";
import { initializeApp, cert, applicationDefault } from "firebase-admin/app";
import { getFirestore, Timestamp } from "firebase-admin/firestore";

// ─── 解析 CLI 参数 ────────────────────────────────────────────────────────────

function parseArgs(argv) {
  const result = {};
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg.startsWith("--")) {
      const key = arg.slice(2);
      const next = argv[i + 1];
      if (!next || next.startsWith("--")) {
        result[key] = true; // 布尔 flag
      } else {
        result[key] = next;
        i++;
      }
    }
  }
  return result;
}

const args = parseArgs(process.argv.slice(2));
const deactivateOnly = Boolean(args["deactivate-only"]);
const listOnly = Boolean(args["list"]);

// ─── 参数校验 ─────────────────────────────────────────────────────────────────

if (!deactivateOnly && !listOnly) {
  if (!args["title"]) {
    console.error("✗ 缺少 --title");
    process.exit(1);
  }
  if (!args["words"]) {
    console.error("✗ 缺少 --words（逗号分隔三个词，如 秋,霜,归）");
    process.exit(1);
  }
}

const title = args["title"];
const words = args["words"]
  ? args["words"].split(",").map((w) => w.trim())
  : [];

if (!deactivateOnly && !listOnly && words.length !== 3) {
  console.error(`✗ --words 需恰好 3 个词，当前 ${words.length} 个`);
  process.exit(1);
}

const days = parseInt(args["days"] ?? "7", 10);
if (!deactivateOnly && !listOnly && (isNaN(days) || days <= 0)) {
  console.error("✗ --days 需为正整数");
  process.exit(1);
}

const customId = args["id"] ?? null;

const startAt = args["start"] ? new Date(args["start"]) : new Date();
if (!deactivateOnly && !listOnly && isNaN(startAt.getTime())) {
  console.error("✗ --start 日期格式无效（推荐 ISO 8601，如 2026-06-10T00:00:00+08:00）");
  process.exit(1);
}
const endAt = new Date(startAt.getTime() + days * 24 * 60 * 60 * 1000);

// ─── 代理（国内网络直连 Google 会 ETIMEDOUT）────────────────────────────────────

// grpc-js 在创建 channel 时读取 grpc_proxy / https_proxy 环境变量做 HTTP CONNECT 隧道。
// 必须在 getFirestore 首次请求前设置，这里在 initializeApp 之前注入。
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

// ─── 初始化 Admin SDK ─────────────────────────────────────────────────────────

// 凭证查找顺序：--creds 参数 → 环境变量 → 当前目录自动检测 *adminsdk*.json
function resolveCredPath() {
  if (args["creds"]) return resolve(args["creds"]);
  if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    return process.env.GOOGLE_APPLICATION_CREDENTIALS;
  }
  // 自动在当前工作目录（functions/）下找 adminsdk JSON
  try {
    const found = readdirSync(process.cwd()).find(
      (f) => f.includes("adminsdk") && f.endsWith(".json"),
    );
    if (found) {
      const full = resolve(process.cwd(), found);
      console.log(`  (自动检测到凭证文件: ${found})`);
      return full;
    }
  } catch {}
  return null;
}

const credPath = resolveCredPath();
if (!credPath) {
  console.error("✗ 未找到凭证文件。请用 --creds <path> 指定，或将 adminsdk JSON 放在 functions/ 目录下。");
  process.exit(1);
}

const app = initializeApp({
  credential: cert(credPath),
  projectId: 'inkite-demo',
});
const db = getFirestore(app);

// ─── 仅列出集合现状（诊断用）─────────────────────────────────────────────────────

if (listOnly) {
  const all = await db
    .collection("challenges")
    .orderBy("startAt", "desc")
    .get();
  console.log(`\nchallenges 集合共 ${all.size} 个文档（按 startAt 倒序）：\n`);
  all.docs.forEach((doc) => {
    const d = doc.data();
    const ts = (t) => (t?.toDate ? t.toDate().toISOString() : String(t));
    console.log(`  id=${doc.id}`);
    console.log(`    title:    ${d.title}`);
    console.log(`    words:    [${(d.words ?? []).join(", ")}]`);
    console.log(`    isActive: ${d.isActive}`);
    console.log(`    startAt:  ${ts(d.startAt)}`);
    console.log(`    endAt:    ${ts(d.endAt)}`);
    console.log("");
  });
  const activeCount = all.docs.filter((doc) => doc.data().isActive === true).length;
  console.log(`其中 isActive=true 的有 ${activeCount} 个（watchActive 应只取 startAt 最大的那一个）。`);

  // 复现 app 的 watchActive 查询，确认是否缺复合索引
  console.log("\n── 复现 watchActive 查询 (where isActive==true + orderBy startAt desc) ──");
  try {
    const q = await db
      .collection("challenges")
      .where("isActive", "==", true)
      .orderBy("startAt", "desc")
      .limit(1)
      .get();
    if (q.empty) {
      console.log("  查询成功但无结果。");
    } else {
      const d = q.docs[0].data();
      console.log(`  ✓ 查询成功，返回: "${d.title}"  → 说明索引存在，问题在别处（缓存？）`);
    }
  } catch (e) {
    console.log(`  ✗ 查询失败: ${e.message}`);
    console.log("    若提示 requires an index / FAILED_PRECONDITION，即确诊缺复合索引。");
  }
  process.exit(0);
}

// ─── 停用旧活跃挑战 ───────────────────────────────────────────────────────────

const activeSnap = await db
  .collection("challenges")
  .where("isActive", "==", true)
  .get();

if (!activeSnap.empty) {
  const batch = db.batch();
  activeSnap.docs.forEach((doc) => {
    batch.update(doc.ref, { isActive: false });
  });
  await batch.commit();
  console.log(`✓ 已将 ${activeSnap.size} 条旧挑战设为 isActive=false`);
  activeSnap.docs.forEach((doc) => {
    const d = doc.data();
    console.log(`    └─ ${doc.id}  "${d.title}"  words=[${(d.words ?? []).join(", ")}]`);
  });
} else {
  console.log("  (无旧活跃挑战)");
}

if (deactivateOnly) {
  console.log("✓ --deactivate-only 模式，跳过创建。");
  process.exit(0);
}

// ─── 写入新挑战 ───────────────────────────────────────────────────────────────

const colRef = db.collection("challenges");
const docRef = customId ? colRef.doc(customId) : colRef.doc();

await docRef.set({
  title,
  words,
  startAt: Timestamp.fromDate(startAt),
  endAt: Timestamp.fromDate(endAt),
  isActive: true,
  createdAt: Timestamp.fromDate(new Date()),
});

console.log(`\n✓ 新挑战已写入 Firestore`);
console.log(`  id:      ${docRef.id}`);
console.log(`  title:   ${title}`);
console.log(`  words:   [${words.join(", ")}]`);
console.log(`  startAt: ${startAt.toISOString()}`);
console.log(`  endAt:   ${endAt.toISOString()}  (+${days} 天)`);

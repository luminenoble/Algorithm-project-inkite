// 「开拓」栏角色卡离线导入脚本（方案 A：ISR-scraper → Firestore charactersCache）。
//
// 一次性离线工具：本地起 ISR 后端 → 跑 /search/cards 聚合 → 灌进 Firestore →
// 关掉。运行期 app 只读 Firestore，不依赖任何在线后端（CLAUDE.md §6 零成本）。
//
// 前置（在 ISR-scraper 侧，见 docs/角色查询-todo.md §3.1）：
//   1. docker-compose up -d              # 起 ES + Mongo + Tika
//   2. uvicorn api.main:app --port 8000  # 起 FastAPI
//   3. python jobs/export_characters.py --top 3000
//      → 输出 functions/scripts/seed/characters_input.json（本脚本默认输入）
//
// 凭证（与 seed_challenge.mjs 同策略，三选一自动查找）：
//   1. --creds <path>                       直接传 service account JSON
//   2. GOOGLE_APPLICATION_CREDENTIALS 环境变量
//   3. functions/ 目录下自动检测 *adminsdk*.json
//   （--emulator 模式下不需要真实凭证）
//
// 跑法（在 functions/ 下）：
//   # 先在 Firestore Emulator 跑通（零成本验证；需另开 `firebase emulators:start`）
//   node scripts/import_characters.mjs --emulator
//   # 验证无误后写线上（国内需挂代理走 grpc）
//   node scripts/import_characters.mjs --proxy http://127.0.0.1:7890
//   # 自定义参数
//   node scripts/import_characters.mjs --input ./seed/characters_input.json \
//        --isr http://localhost:8000 --size 8 --reddit 5 --limit 500 --dry-run

import { readdirSync, readFileSync } from "node:fs";
import { resolve } from "node:path";
import { initializeApp, cert } from "firebase-admin/app";
import { getFirestore, FieldValue } from "firebase-admin/firestore";

// ─── CLI 解析 ─────────────────────────────────────────────────────────────────

function parseArgs(argv) {
  const result = {};
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (!arg.startsWith("--")) continue;
    const key = arg.slice(2);
    const next = argv[i + 1];
    if (!next || next.startsWith("--")) {
      result[key] = true;
    } else {
      result[key] = next;
      i++;
    }
  }
  return result;
}

const args = parseArgs(process.argv.slice(2));
const ISR_BASE = (args["isr"] ?? "http://localhost:8000").replace(/\/$/, "");
const INPUT = args["input"] ?? "./seed/characters_input.json";
const CARDS_SIZE = parseInt(args["size"] ?? "8", 10);
const REDDIT_MAX = parseInt(args["reddit"] ?? "5", 10);
const LIMIT = args["limit"] ? parseInt(args["limit"], 10) : Infinity;
const SUMMARY_MAX = parseInt(args["summary-max"] ?? "800", 10);
const dryRun = Boolean(args["dry-run"]);
const useEmulator =
  Boolean(args["emulator"]) || Boolean(process.env.FIRESTORE_EMULATOR_HOST);

// ─── 字段工具 ─────────────────────────────────────────────────────────────────

/// normalize 角色名 → 文档 ID：小写、去标点、空白合并为单下划线。
/// 例 "Hu Tao" → "hu_tao"（design.md §7 约定，与 ISR doc_id=sha1(url) 不同）。
function normalizeKey(name) {
  return name
    .toLowerCase()
    .trim()
    .replace(/[^\p{L}\p{N}\s]/gu, "") // 去标点（保留 Unicode 字母/数字）
    .replace(/\s+/g, "_")
    .replace(/^_+|_+$/g, "");
}

/// 生成 searchTokens：整名累进前缀（含空格，上限 12）+ 各分词累进前缀（上限 12）。
/// app 端 `where('searchTokens', arrayContains: queryLower)` 做前缀搜索。
function buildSearchTokens(name) {
  const lower = name.toLowerCase().trim();
  const tokens = new Set();
  const PREFIX_CAP = 12;

  const addPrefixes = (str) => {
    const cap = Math.min(str.length, PREFIX_CAP);
    for (let i = 1; i <= cap; i++) tokens.add(str.slice(0, i));
  };

  if (lower) addPrefixes(lower); // 整名（含空格）累进前缀
  for (const part of lower.split(/\s+/).filter(Boolean)) {
    addPrefixes(part); // 各分词累进前缀，让 "tao" 也能召回 "Hu Tao"
  }
  return [...tokens];
}

// ─── ISR API 客户端 ───────────────────────────────────────────────────────────

async function isrGet(path) {
  const res = await fetch(`${ISR_BASE}${path}`);
  if (!res.ok) {
    throw new Error(`ISR ${path} → HTTP ${res.status}`);
  }
  return res.json();
}

async function checkIsrAlive() {
  try {
    const h = await isrGet("/health");
    if (!h.ok) throw new Error(JSON.stringify(h));
    console.log(`  ISR /health OK（索引 ${h.index}，doc_count=${h.doc_count}）`);
  } catch (e) {
    console.error(
      `✗ 无法连接 ISR 后端（${ISR_BASE}）：${e.message}\n` +
        "  请先在 ISR-scraper 侧：docker-compose up -d && uvicorn api.main:app --port 8000",
    );
    process.exit(1);
  }
}

// 缓存 /doc/{id} 结果，避免同一文档重复请求。
const docCache = new Map();
async function getDoc(docId) {
  if (docCache.has(docId)) return docCache.get(docId);
  let detail = null;
  try {
    detail = await isrGet(`/doc/${encodeURIComponent(docId)}?body_max=${SUMMARY_MAX}`);
  } catch {
    detail = null; // 单文档失败不致命，降级
  }
  docCache.set(docId, detail);
  return detail;
}

/// 把某角色名的 hits 聚合成一个 CharacterCache 文档（不含 cachedAt）。
async function buildCharacterDoc(name) {
  const cards = await isrGet(
    `/search/cards?q=${encodeURIComponent(name)}&size=${CARDS_SIZE}`,
  );
  const hits = cards.hits ?? [];
  if (hits.length === 0) return null;

  // 主条目：source ∈ {wikipedia,fandom} 且 tag=canon 的最高分；逐级回退。
  const officialCanon = hits.find(
    (h) => ["wikipedia", "fandom"].includes((h.source ?? "").toLowerCase()) &&
      (h.tag ?? "").toLowerCase() === "canon",
  );
  const official = hits.find((h) =>
    ["wikipedia", "fandom"].includes((h.source ?? "").toLowerCase()),
  );
  const main = officialCanon ?? official ?? hits[0];

  const mainDetail = await getDoc(main.doc_id);
  let wikiSummary = (main.snippet_plain ?? "").trim();
  if (!wikiSummary && mainDetail?.body) {
    wikiSummary = mainDetail.body.slice(0, SUMMARY_MAX).trim();
  }
  const wikiUrl = (mainDetail?.url ?? "").trim();

  // redditPosts：reddit/ao3 hits 前 N 项，逐条 /doc 补 url。
  const fanHits = hits
    .filter((h) => ["reddit", "ao3"].includes((h.source ?? "").toLowerCase()))
    .slice(0, REDDIT_MAX);
  const redditPosts = [];
  for (const h of fanHits) {
    const d = await getDoc(h.doc_id);
    redditPosts.push({
      title: (h.title ?? "").trim(),
      url: (d?.url ?? "").trim(),
      snippet: (h.snippet_plain ?? "").trim(),
      source: (h.source ?? "").toLowerCase(),
      tag: (h.tag ?? "").toLowerCase(),
    });
  }

  return {
    name: name.trim(),
    wikiSummary,
    wikiUrl,
    redditPosts,
    source: (main.source ?? "").toLowerCase(),
    tag: (main.tag ?? "").toLowerCase(),
    popularity: Number(mainDetail?.popularity ?? 0) || 0,
    obscurity: Number(mainDetail?.obscurity ?? 0) || 0,
    searchTokens: buildSearchTokens(name),
  };
}

// ─── 凭证 / 初始化 ────────────────────────────────────────────────────────────

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

function initFirestore() {
  if (useEmulator) {
    if (!process.env.FIRESTORE_EMULATOR_HOST) {
      process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
    }
    console.log(
      `  (Emulator 模式 → FIRESTORE_EMULATOR_HOST=${process.env.FIRESTORE_EMULATOR_HOST})`,
    );
    const app = initializeApp({ projectId: "inkite-demo" });
    return getFirestore(app);
  }

  // 线上：国内直连 Google 会 ETIMEDOUT，需 grpc 代理。
  const proxy =
    args["proxy"] || process.env.grpc_proxy || process.env.https_proxy ||
    process.env.HTTPS_PROXY;
  if (proxy) {
    process.env.grpc_proxy = proxy;
    process.env.https_proxy = proxy;
    console.log(`  (使用代理: ${proxy})`);
  }
  const credPath = resolveCredPath();
  if (!credPath) {
    console.error(
      "✗ 未找到凭证。用 --creds <path> 指定，或把 *adminsdk*.json 放 functions/，或加 --emulator。",
    );
    process.exit(1);
  }
  const app = initializeApp({ credential: cert(credPath), projectId: "inkite-demo" });
  return getFirestore(app);
}

// ─── 主流程 ───────────────────────────────────────────────────────────────────

console.log("== 「开拓」角色卡导入 ==");
console.log(`  ISR:   ${ISR_BASE}`);
console.log(`  输入:  ${resolve(INPUT)}`);
console.log(`  写入:  ${useEmulator ? "Firestore Emulator" : "线上 inkite-demo"}${dryRun ? " (dry-run，不实写)" : ""}`);

let inputRaw;
try {
  inputRaw = readFileSync(resolve(INPUT), "utf-8");
} catch (e) {
  console.error(
    `✗ 读不到角色清单 ${resolve(INPUT)}：${e.message}\n` +
      "  请先在 ISR 侧跑 python jobs/export_characters.py 生成。",
  );
  process.exit(1);
}
let roster = JSON.parse(inputRaw);
if (!Array.isArray(roster)) {
  console.error("✗ 角色清单不是数组，格式异常。");
  process.exit(1);
}
roster = roster.filter((c) => c && c.name && String(c.name).trim());
if (Number.isFinite(LIMIT)) roster = roster.slice(0, LIMIT);
console.log(`  清单角色数: ${roster.length}\n`);

await checkIsrAlive();

const db = dryRun ? null : initFirestore();
const writer = dryRun ? null : db.bulkWriter();

let ok = 0;
let skipped = 0;
const failures = [];
const seenKeys = new Set();

for (let i = 0; i < roster.length; i++) {
  const name = String(roster[i].name).trim();
  const key = normalizeKey(name);
  if (!key) {
    failures.push(`${name}（normalize 后为空）`);
    continue;
  }
  if (seenKeys.has(key)) {
    skipped++; // 同名归一后重复，跳过
    continue;
  }
  try {
    const doc = await buildCharacterDoc(name);
    if (!doc) {
      failures.push(`${name}（ISR 无命中）`);
      continue;
    }
    seenKeys.add(key);
    if (!dryRun) {
      writer.set(
        db.collection("charactersCache").doc(key),
        { ...doc, cachedAt: FieldValue.serverTimestamp() },
        { merge: true },
      );
    }
    ok++;
    if (ok % 50 === 0 || i === roster.length - 1) {
      console.log(`  [${i + 1}/${roster.length}] 已聚合 ${ok}，跳过 ${skipped}，失败 ${failures.length}`);
    }
  } catch (e) {
    failures.push(`${name}（${e.message}）`);
  }
}

if (!dryRun) {
  await writer.close();
}

console.log(`\n✓ 完成：写入 ${ok}，跳过(同名) ${skipped}，失败 ${failures.length}`);
if (failures.length) {
  console.log("  失败/跳过名单（前 30）：");
  failures.slice(0, 30).forEach((f) => console.log(`    - ${f}`));
}
if (dryRun) {
  console.log("\n(dry-run：未实际写 Firestore。去掉 --dry-run 正式导入。)");
}

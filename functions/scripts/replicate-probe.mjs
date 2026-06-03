// Replicate flux-schnell 探针：绕开 Cloud Function 与 app，直接打模型接口，
// 用来判断「出图差」到底是平台/模型问题，还是我们这边（prompt / 参数 / Storage 转存）。
//
// 跑法（在 functions/ 下，Node 20 自带 fetch）：
//   cd functions
//   export REPLICATE_API_TOKEN=$(firebase functions:secrets:access REPLICATE_API_TOKEN)
//   node scripts/replicate-probe.mjs
//
// 原图存到 functions/scripts/out/*.png，逐张肉眼看。out/ 不要入仓。

import { writeFile, mkdir } from "node:fs/promises";

// 容错：firebase functions:secrets:access 有时会把报错文字一起打到 stdout，
// 被 $(...) 一并塞进环境变量，导致 token 里混入换行/杂讯 → header 非法。
// 这里只抽 r8_ 开头的纯 token。
const raw = (process.env.REPLICATE_API_TOKEN || "").trim();
const matched = raw.match(/r8_[A-Za-z0-9]+/);
const token = matched ? matched[0] : raw;
if (!token) {
  console.error("✗ 缺 REPLICATE_API_TOKEN 环境变量");
  process.exit(1);
}
if (/\s/.test(token)) {
  console.error("✗ token 含空白/换行，环境变量可能混入了杂讯，请用干净 token");
  process.exit(1);
}

const outDir = new URL("./out/", import.meta.url);

// 三个对照用例：
// 1 基准——最常规的写实题材，FLUX 必须能画好；画不好 = 平台/账号/请求问题。
// 2 折纸鹤——具体、英文、明确主体；测 FLUX 对「折纸」概念的能力。
// 3 我们的模板——按 generateOrigami 的 F2 模板拼，关键词用普通英文名词。
const cases = [
  {
    name: "1-sanity-apple",
    prompt:
      "a hyper-detailed product photo of a single red apple on a white wooden table, soft daylight, shallow depth of field",
  },
  {
    name: "2-origami-crane",
    prompt:
      "a single folded origami paper crane made of crisp white paper, on a plain light gray studio background, soft even lighting, centered, photographed top-down, highly detailed",
  },
  {
    name: "3-template-words",
    prompt:
      "a single delicate folded origami paper sculpture inspired by lighthouse, waves, dusk, " +
      "crisp clean paper folds, handmade washi paper texture, plain off-white studio backdrop, " +
      "soft even lighting, centered composition, photographed top-down, highly detailed product photo",
  },
  {
    // 复刻你 demo 的关键词（furina, moon, cloud），用线上同款 F2 模板拼。
    name: "4-furina-moon-cloud",
    prompt:
      "a single delicate folded origami paper sculpture inspired by furina, moon, cloud, " +
      "crisp clean paper folds, handmade washi paper texture, plain off-white studio backdrop, " +
      "soft even lighting, centered composition, photographed top-down, highly detailed product photo",
  },
];

// 质量旋钮：go_fast=false 走 bf16（比默认 fp8 更精细，慢一点）；
// disable_safety_checker=true 排除「安全检查误杀返回空白图」的可能。
const baseInput = {
  aspect_ratio: "1:1",
  output_format: "png",
  num_outputs: 1,
  go_fast: false,
  disable_safety_checker: true,
};

async function run(c) {
  const res = await fetch(
    "https://api.replicate.com/v1/models/black-forest-labs/flux-schnell/predictions",
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
        Prefer: "wait",
      },
      body: JSON.stringify({ input: { ...baseInput, prompt: c.prompt } }),
    },
  );
  const json = await res.json();
  if (!res.ok) {
    console.error(`[${c.name}] ✗ HTTP ${res.status}: ${JSON.stringify(json)}`);
    return;
  }
  const url = Array.isArray(json.output) ? json.output[0] : json.output;
  console.log(`[${c.name}] status=${json.status}`);
  console.log(`  url=${url}`);
  if (typeof url === "string") {
    const img = await fetch(url);
    const buf = Buffer.from(await img.arrayBuffer());
    await mkdir(outDir, { recursive: true });
    await writeFile(new URL(`${c.name}.png`, outDir), buf);
    console.log(`  saved scripts/out/${c.name}.png (${buf.length} bytes)`);
  }
}

for (const c of cases) {
  try {
    await run(c);
  } catch (e) {
    console.error(`[${c.name}] ✗ error: ${e}`);
  }
}
console.log("\ndone — 打开 functions/scripts/out/*.png 逐张看效果。");

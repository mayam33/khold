/**
 * Khold level server — Cloudflare Workers + D1 edition.
 *
 * It mirrors server/server.py so the game can point its "server URL" at
 * https://<worker>.<account>.workers.dev without any client changes.
 *
 * Routes:
 *   GET  /                     plain-text banner
 *   GET  /health               visible level count
 *   GET  /levels?limit&offset  public level list
 *   GET  /levels/:id           full level payload
 *   POST /levels               publish a level
 *   POST /levels/:id/rate      rate 1..5 (one rating per client)
 *   POST /levels/:id/report    report (3 distinct reports hide it)
 *   POST /levels/:id/play      increment play counter
 */

const MAX_BODY = 256 * 1024;
const MAX_NAME = 60;
const MAX_AUTHOR = 40;
const MIN_W = 7;
const MAX_W = 24;
const MIN_H = 7;
const MAX_H = 32;
const ALLOWED = new Set(Array.from(". SRFE#*PpEeFfRrSs"));
const REPORT_HIDE_THRESHOLD = 3;

function corsHeaders() {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type, Accept",
  };
}

function jsonResponse(code, payload) {
  return new Response(JSON.stringify(payload), {
    status: code,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "no-store",
      ...corsHeaders(),
    },
  });
}

function errorResponse(code, message) {
  return jsonResponse(code, { ok: false, error: message });
}

function levelRow(row) {
  const count = Number(row.rating_count || 0);
  const rating = count ? Math.round((Number(row.rating_sum || 0) / count) * 100) / 100 : 0;
  return {
    id: String(row.id),
    name: String(row.name),
    author: String(row.author),
    created_at: Number(row.created_at),
    plays: Number(row.plays),
    rating,
    rating_count: count,
  };
}

function validateLevel(payload) {
  const name = typeof payload.name === "string" ? payload.name.trim() : "";
  const author = typeof payload.author === "string" ? payload.author.trim() : "";
  if (!name || name.length > MAX_NAME) {
    return "اسم المرحلة مطلوب (حتى 60 حرفًا).";
  }
  if (!author || author.length > MAX_AUTHOR) {
    return "اسم المؤلف مطلوب (حتى 40 حرفًا).";
  }
  const data = payload.data;
  if (data === null || typeof data !== "object" || Array.isArray(data)) {
    return "بيانات المرحلة مفقودة.";
  }
  const rows = data.rows;
  if (!Array.isArray(rows) || rows.length === 0 || !rows.every((r) => typeof r === "string")) {
    return "صفوف المرحلة غير صالحة.";
  }
  const h = rows.length;
  const w = rows[0].length;
  if (w < MIN_W || w > MAX_W || h < MIN_H || h > MAX_H) {
    return "أبعاد المرحلة غير مدعومة.";
  }
  if (rows.some((r) => r.length !== w)) {
    return "صفوف المرحلة غير متساوية الطول.";
  }
  const joined = rows.join("");
  if (joined.length > MAX_W * MAX_H) {
    return "المرحلة كبيرة جدًا.";
  }
  for (const ch of joined) {
    if (!ALLOWED.has(ch)) {
      return "تحتوي المرحلة على رموز غير مسموحة.";
    }
  }
  const countOf = (chars) => Array.from(joined).filter((c) => chars.includes(c)).length;
  if (countOf("Pp") !== 1) {
    return "يجب أن تحتوي المرحلة على نقطة بداية واحدة.";
  }
  if (countOf("Ee") !== 1) {
    return "يجب أن تحتوي المرحلة على مخرج واحد.";
  }
  if (countOf("Ff*") < 1) {
    return "يجب أن تحتوي المرحلة على ثمرة واحدة على الأقل.";
  }
  const encoded = new TextEncoder().encode(JSON.stringify(data));
  if (encoded.length > MAX_BODY) {
    return "بيانات المرحلة كبيرة جدًا.";
  }
  return null;
}

async function readJson(request) {
  const declared = Number(request.headers.get("content-length") || 0);
  if (declared > MAX_BODY) {
    throw new Error("body too large");
  }
  const text = await request.text();
  if (new TextEncoder().encode(text).length > MAX_BODY) {
    throw new Error("body too large");
  }
  if (!text) {
    return {};
  }
  try {
    return JSON.parse(text);
  } catch {
    throw new Error("invalid json");
  }
}

function clientId(request, payload) {
  let cid = typeof payload.client === "string" ? payload.client.trim() : "";
  if (!cid || cid.length > 64) {
    const ip = request.headers.get("CF-Connecting-IP") || "unknown";
    cid = "ip:" + ip;
  }
  return cid;
}

async function countVisible(env) {
  const row = await env.DB.prepare("SELECT COUNT(*) AS c FROM levels WHERE hidden=0").first();
  return Number(row ? row.c : 0);
}

async function listLevels(url, env) {
  const rawLimit = Number(url.searchParams.get("limit") || 50);
  const rawOffset = Number(url.searchParams.get("offset") || 0);
  const limit = Number.isFinite(rawLimit) ? Math.max(1, Math.min(100, Math.trunc(rawLimit))) : 50;
  const offset = Number.isFinite(rawOffset) ? Math.max(0, Math.trunc(rawOffset)) : 0;
  const query = await env.DB.prepare(
    "SELECT * FROM levels WHERE hidden=0 ORDER BY created_at DESC LIMIT ? OFFSET ?",
  )
    .bind(limit, offset)
    .all();
  const total = await countVisible(env);
  return jsonResponse(200, {
    ok: true,
    levels: (query.results || []).map(levelRow),
    total,
  });
}

async function getLevel(id, env) {
  const row = await env.DB.prepare("SELECT * FROM levels WHERE id=?").bind(id).first();
  if (!row || Number(row.hidden) !== 0) {
    return errorResponse(404, "المرحلة غير موجودة.");
  }
  let data;
  try {
    data = JSON.parse(row.data);
  } catch {
    return errorResponse(500, "بيانات المرحلة تالفة.");
  }
  return jsonResponse(200, { ...levelRow(row), data });
}

async function createLevel(payload, env) {
  const error = validateLevel(payload);
  if (error) {
    return errorResponse(400, error);
  }
  const id = crypto.randomUUID().replace(/-/g, "").slice(0, 12);
  const name = payload.name.trim();
  const author = payload.author.trim();
  const data = payload.data;
  const clean = {
    w: data.rows[0].length,
    h: data.rows.length,
    rows: data.rows,
    par: Number.parseInt(data.par, 10) || 0,
  };
  const now = Date.now() / 1000;
  await env.DB.prepare(
    "INSERT INTO levels (id, name, author, data, created_at) VALUES (?,?,?,?,?)",
  )
    .bind(id, name, author, JSON.stringify(clean), now)
    .run();
  console.log(`Published ${id} by ${author} (${clean.w}x${clean.h})`);
  return jsonResponse(201, { ok: true, id });
}

async function rateLevel(request, id, payload, env) {
  const score = Number.parseInt(payload.score, 10);
  if (!Number.isFinite(score) || score < 1 || score > 5) {
    return errorResponse(400, "التقييم يجب أن يكون من 1 إلى 5.");
  }
  const row = await env.DB.prepare("SELECT hidden FROM levels WHERE id=?").bind(id).first();
  if (!row || Number(row.hidden) !== 0) {
    return errorResponse(404, "المرحلة غير موجودة.");
  }
  const client = clientId(request, payload);
  await env.DB.prepare(
    "INSERT INTO ratings (level_id, client, score) VALUES (?,?,?) " +
      "ON CONFLICT(level_id, client) DO UPDATE SET score=excluded.score",
  )
    .bind(id, client, score)
    .run();
  const agg = await env.DB.prepare(
    "SELECT SUM(score) AS s, COUNT(*) AS c FROM ratings WHERE level_id=?",
  )
    .bind(id)
    .first();
  const total = Number(agg && agg.s ? agg.s : 0);
  const count = Number(agg && agg.c ? agg.c : 0);
  await env.DB.prepare("UPDATE levels SET rating_sum=?, rating_count=? WHERE id=?")
    .bind(total, count, id)
    .run();
  const rating = count ? Math.round((total / count) * 100) / 100 : 0;
  return jsonResponse(200, { ok: true, rating, rating_count: count });
}

async function reportLevel(request, id, payload, env) {
  const client = clientId(request, payload);
  const reason = typeof payload.reason === "string" ? payload.reason.slice(0, 120) : "";
  const row = await env.DB.prepare("SELECT hidden FROM levels WHERE id=?").bind(id).first();
  if (!row) {
    return errorResponse(404, "المرحلة غير موجودة.");
  }
  await env.DB.prepare(
    "INSERT OR IGNORE INTO reports (level_id, client, reason, created_at) VALUES (?,?,?,?)",
  )
    .bind(id, client, reason, Date.now() / 1000)
    .run();
  const countRow = await env.DB.prepare(
    "SELECT COUNT(*) AS c FROM reports WHERE level_id=?",
  )
    .bind(id)
    .first();
  const count = Number(countRow ? countRow.c : 0);
  const hidden = count >= REPORT_HIDE_THRESHOLD;
  if (hidden) {
    await env.DB.prepare("UPDATE levels SET hidden=1 WHERE id=?").bind(id).run();
  }
  return jsonResponse(200, { ok: true, reports: count, hidden });
}

async function playLevel(id, env) {
  await env.DB.prepare("UPDATE levels SET plays=plays+1 WHERE id=?").bind(id).run();
  return jsonResponse(200, { ok: true });
}

async function handleGet(request, url, env) {
  const parts = url.pathname.split("/").filter(Boolean);
  if (url.pathname === "/" || url.pathname === "") {
    return new Response(
      "Khold level server is running.\nAPI: GET /health, GET /levels, GET /levels/{id}\n",
      {
        status: 200,
        headers: { "Content-Type": "text/plain; charset=utf-8", ...corsHeaders() },
      },
    );
  }
  if (parts.length === 1 && parts[0] === "health") {
    return jsonResponse(200, { ok: true, levels: await countVisible(env) });
  }
  if (parts.length === 1 && parts[0] === "levels") {
    return listLevels(url, env);
  }
  if (parts.length === 2 && parts[0] === "levels") {
    return getLevel(decodeURIComponent(parts[1]), env);
  }
  return errorResponse(404, "المسار غير موجود.");
}

async function handlePost(request, url, env) {
  const parts = url.pathname.split("/").filter(Boolean);
  let payload;
  try {
    payload = await readJson(request);
  } catch {
    return errorResponse(413, "الطلب كبير جدًا أو غير صالح.");
  }
  if (payload === null || typeof payload !== "object" || Array.isArray(payload)) {
    return errorResponse(400, "صيغة الطلب غير صالحة.");
  }
  if (parts.length === 1 && parts[0] === "levels") {
    return createLevel(payload, env);
  }
  if (parts.length === 3 && parts[0] === "levels") {
    const id = decodeURIComponent(parts[1]);
    const action = parts[2];
    if (action === "rate") {
      return rateLevel(request, id, payload, env);
    }
    if (action === "report") {
      return reportLevel(request, id, payload, env);
    }
    if (action === "play") {
      return playLevel(id, env);
    }
  }
  return errorResponse(404, "المسار غير موجود.");
}

export default {
  async fetch(request, env) {
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: corsHeaders() });
    }
    const url = new URL(request.url);
    try {
      if (request.method === "GET") {
        return await handleGet(request, url, env);
      }
      if (request.method === "POST") {
        return await handlePost(request, url, env);
      }
      return errorResponse(405, "الطريقة غير مدعومة.");
    } catch (error) {
      console.error("Worker error:", error);
      return errorResponse(500, "خطأ داخلي في الخادم.");
    }
  },
};

/**
 * Production AI-generation SELF-TEST (run on the EC2 instance via SSM).
 *
 * Exercises the REAL end-to-end pipeline against the running backend on
 * loopback: creates an isolated test user, uploads a real image to S3, mints a
 * consumer JWT, submits a generation, and polls to a terminal state — then
 * prints a non-secret JSON summary (status, error code, whether an image URL
 * came back). No secrets are printed. Uses a dedicated test user so no real
 * user's credits/content are touched.
 *
 * Run: `cd <backend> && node scripts/gen-selftest.mjs`
 */
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { PrismaClient } from '@prisma/client';
import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3';
import jwt from 'jsonwebtoken';

// --- load .env (simple KEY=VALUE; ignores the single-quoted SA JSON line) ----
const envPath = path.resolve(process.cwd(), '.env');
const env = {};
for (const line of fs.readFileSync(envPath, 'utf8').split('\n')) {
  const m = /^([A-Z0-9_]+)=(.*)$/.exec(line.trim());
  if (m) env[m[1]] = m[2].replace(/^['"]|['"]$/g, '');
}
const DATABASE_URL = env.DATABASE_URL;
const JWT_ACCESS_SECRET = env.JWT_ACCESS_SECRET;
const S3_BUCKET = env.S3_BUCKET;
const AWS_REGION = env.AWS_REGION || 'ap-south-1';
const API = `http://127.0.0.1:${env.PORT || 3000}/v1`;
const TYPE = process.env.SELFTEST_TYPE || 'ai_edit';
const PRESET = process.env.SELFTEST_PRESET || 'cinematic';
const IMAGE = process.env.SELFTEST_IMAGE || path.resolve(process.cwd(), 'public/admin/logo.png');

const out = (o) => console.log('SELFTEST_RESULT ' + JSON.stringify(o));

async function main() {
  if (!DATABASE_URL || !JWT_ACCESS_SECRET || !S3_BUCKET) {
    return out({ ok: false, stage: 'config', error: 'missing DATABASE_URL/JWT/S3 in .env' });
  }
  process.env.DATABASE_URL = DATABASE_URL;
  const prisma = new PrismaClient();
  try {
    // 1) Isolated test user + wallet with credits (idempotent).
    const user = await prisma.user.upsert({
      where: { firebaseUid: '__gen_selftest__' },
      update: {},
      create: { firebaseUid: '__gen_selftest__', email: 'selftest@stylo.local', displayName: 'Self Test', profile: { create: {} }, wallet: { create: { balance: 100 } } },
      include: { wallet: true },
    });
    if (!user.wallet || user.wallet.balance < 20) {
      await prisma.creditWallet.update({ where: { userId: user.id }, data: { balance: 100 } });
    }

    // 2) Upload a real image to S3 under the user's originals/ prefix.
    const bytes = fs.readFileSync(IMAGE);
    const contentType = IMAGE.endsWith('.png') ? 'image/png' : 'image/jpeg';
    const key = `originals/${user.id}/selftest-${Date.now()}.${contentType === 'image/png' ? 'png' : 'jpg'}`;
    const s3 = new S3Client({ region: AWS_REGION });
    await s3.send(new PutObjectCommand({ Bucket: S3_BUCKET, Key: key, Body: bytes, ContentType: contentType }));

    // 3) Mint a consumer access token for the test user.
    const token = jwt.sign({ sub: user.id, fuid: user.firebaseUid, type: 'access' }, JWT_ACCESS_SECRET, { expiresIn: 600 });

    // 4) Submit a generation through the real API.
    const submit = await fetch(`${API}/generations`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}`, 'Idempotency-Key': crypto.randomUUID() },
      body: JSON.stringify({ type: TYPE, mode: 'explore', preset_key: PRESET, user_photo_key: key, options: { resolution: 'standard' } }),
    });
    const submitBody = await submit.json().catch(() => ({}));
    if (!submit.ok) {
      return out({ ok: false, stage: 'submit', http: submit.status, error: submitBody?.error?.code || 'submit_failed', message: (submitBody?.error?.message || '').slice(0, 120) });
    }
    const genId = submitBody.generation_id;

    // 5) Poll to terminal (~120s).
    let status = submitBody.status, errorCode = null, hasImage = false;
    for (let i = 0; i < 40; i++) {
      await new Promise((r) => setTimeout(r, 3000));
      const g = await fetch(`${API}/generations/${genId}`, { headers: { Authorization: `Bearer ${token}` } });
      const gb = await g.json().catch(() => ({}));
      status = gb.status; errorCode = gb.error_code || null;
      hasImage = Array.isArray(gb.images) && gb.images.length > 0 && !!gb.images[0].url;
      if (['succeeded', 'failed', 'refunded'].includes(status)) break;
    }
    return out({ ok: status === 'succeeded', stage: 'completed', generation_id: genId, type: TYPE, status, error_code: errorCode, has_image: hasImage });
  } catch (e) {
    return out({ ok: false, stage: 'exception', error: String(e?.message || e).slice(0, 160) });
  } finally {
    await prisma.$disconnect().catch(() => {});
  }
}
main();

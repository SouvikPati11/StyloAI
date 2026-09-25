/**
 * Creates (or, on explicit request, resets) the FIRST admin account for the
 * StyloAI admin panel — safely, from environment only, so no credential ever
 * appears in source control or logs.
 *
 * Reads:
 *   ADMIN_BOOTSTRAP_EMAIL     — the admin's login email (required to do anything)
 *   ADMIN_BOOTSTRAP_PASSWORD  — the admin's password (required; min 12 chars)
 *   ADMIN_BOOTSTRAP_RESET     — optional; "true"/"1" to reset an EXISTING admin's
 *                               password (recovery / rotation). Off by default.
 *   DATABASE_URL              — standard Prisma connection string.
 *
 * Behaviour:
 *   - If the env vars are not set, it does nothing and exits 0 (so the deploy is
 *     never blocked before the operator has configured the bootstrap).
 *   - If the admin does not exist, it is created with role super_admin.
 *   - If the admin already exists, it is left UNTOUCHED unless RESET is set, in
 *     which case only the password hash is updated. The deploy can therefore run
 *     this every time without ever silently changing a live admin password.
 *   - The password is bcrypt-hashed (cost 12). It is NEVER printed. Only the
 *     email and the action taken are logged.
 *
 * Run: `npm run bootstrap:admin` (ts-node), same mechanism as the seed.
 */
import { PrismaClient, AdminRole } from '@prisma/client';
import * as bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

function isTruthy(v: string | undefined): boolean {
  return v === 'true' || v === '1' || v === 'yes';
}

async function main() {
  const email = process.env.ADMIN_BOOTSTRAP_EMAIL?.trim();
  const password = process.env.ADMIN_BOOTSTRAP_PASSWORD;
  const reset = isTruthy(process.env.ADMIN_BOOTSTRAP_RESET);

  if (!email || !password) {
    console.log(
      '[bootstrap-admin] ADMIN_BOOTSTRAP_EMAIL/PASSWORD not set — nothing to do.',
    );
    return;
  }

  // Minimal, non-secret validation. We never log the password itself.
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) {
    throw new Error('[bootstrap-admin] ADMIN_BOOTSTRAP_EMAIL is not a valid email.');
  }
  if (password.length < 12) {
    throw new Error(
      '[bootstrap-admin] ADMIN_BOOTSTRAP_PASSWORD must be at least 12 characters.',
    );
  }

  const existing = await prisma.adminUser.findUnique({ where: { email } });

  if (!existing) {
    const passwordHash = await bcrypt.hash(password, 12);
    await prisma.adminUser.create({
      data: { email, passwordHash, role: AdminRole.super_admin },
    });
    console.log(`[bootstrap-admin] Created super_admin: ${email}`);
    return;
  }

  if (reset) {
    const passwordHash = await bcrypt.hash(password, 12);
    await prisma.adminUser.update({
      where: { email },
      data: { passwordHash, isActive: true },
    });
    console.log(
      `[bootstrap-admin] Reset password for existing admin: ${email} (ADMIN_BOOTSTRAP_RESET was set).`,
    );
    return;
  }

  console.log(
    `[bootstrap-admin] Admin already exists: ${email} — left unchanged (set ADMIN_BOOTSTRAP_RESET=true to rotate the password).`,
  );
}

main()
  .catch((e) => {
    console.error(e instanceof Error ? e.message : e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });

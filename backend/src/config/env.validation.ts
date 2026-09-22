/**
 * Validates required environment variables at boot. Fails fast with a clear
 * message rather than surfacing confusing runtime errors later. Secrets are
 * documented in docs/ENVIRONMENT.md and never committed.
 */
export function validateEnv(config: Record<string, unknown>): Record<string, unknown> {
  const required = ['DATABASE_URL', 'JWT_ACCESS_SECRET', 'JWT_REFRESH_SECRET'];
  const missing = required.filter((k) => !config[k] || String(config[k]).length === 0);
  if (missing.length > 0) {
    throw new Error(`Missing required environment variables: ${missing.join(', ')}`);
  }
  return config;
}

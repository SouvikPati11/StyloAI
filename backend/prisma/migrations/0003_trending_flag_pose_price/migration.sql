-- Additive, non-destructive. Adds a Home "Trending" feature flag to styles and a
-- per-pose credit price. No existing rows are modified or removed.
ALTER TABLE "trending_content" ADD COLUMN IF NOT EXISTS "is_trending" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "poses" ADD COLUMN IF NOT EXISTS "credit_price" INTEGER;

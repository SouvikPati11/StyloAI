-- Additive, non-destructive. Extends trending content with description, tags,
-- and an authoritative per-item credit price, and introduces the separate,
-- free Pose content type. No existing rows are modified or removed.

-- TrendingContent: description, tags, per-item credit price
ALTER TABLE "trending_content" ADD COLUMN IF NOT EXISTS "description" TEXT;
ALTER TABLE "trending_content" ADD COLUMN IF NOT EXISTS "tags" TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[];
ALTER TABLE "trending_content" ADD COLUMN IF NOT EXISTS "credit_price" INTEGER;

-- Poses: a separate, free reference-content table
CREATE TABLE IF NOT EXISTS "poses" (
    "id" UUID NOT NULL,
    "title" TEXT NOT NULL,
    "description" TEXT,
    "image_s3_key" TEXT NOT NULL,
    "pose_type" TEXT,
    "tags" TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
    "position" INTEGER NOT NULL DEFAULT 0,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_by" UUID,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,
    CONSTRAINT "poses_pkey" PRIMARY KEY ("id")
);
CREATE INDEX IF NOT EXISTS "poses_is_active_position_idx" ON "poses" ("is_active", "position");

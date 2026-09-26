# Admin image upload — required S3 CORS

The Admin panel (StyloAI Studio, served at `https://api.souvikpati.in/admin/`)
uploads trending-style and pose images **directly from the browser** to S3 using
a short-lived pre-signed `PUT` URL. Browsers enforce CORS on that cross-origin
`PUT`, so the S3 bucket must allow it from the admin origin.

> The mobile app is **not** affected: it uploads with a native HTTP client (Dio),
> which is not subject to browser CORS. This is why the app can upload but the
> browser admin panel could not.

## Symptom

In Trending Styles / Poses, choosing an image and clicking Publish shows an
error like:

> Upload to storage was blocked by the browser (likely S3 CORS). The S3 bucket
> must allow PUT from https://api.souvikpati.in.

## Fix — add a CORS rule to the media bucket

Bucket: `styloai-prod-assets-2026` (value of `S3_BUCKET`).

`s3-cors.json`:

```json
[
  {
    "AllowedOrigins": ["https://api.souvikpati.in"],
    "AllowedMethods": ["PUT", "GET"],
    "AllowedHeaders": ["*"],
    "ExposeHeaders": ["ETag"],
    "MaxAgeSeconds": 3000
  }
]
```

Apply it (requires `s3:PutBucketCors` on the bucket):

```bash
aws s3api put-bucket-cors \
  --bucket styloai-prod-assets-2026 \
  --cors-configuration file://s3-cors.json \
  --region ap-south-1
```

Verify:

```bash
aws s3api get-bucket-cors --bucket styloai-prod-assets-2026 --region ap-south-1
```

After this, re-open the admin panel and upload again — it should succeed, the
preview should render, the image should persist across refresh, and the mobile
app will render it via the signed download URL.

Notes:
- Only `PUT` and `GET` are needed. Do **not** open the bucket publicly; objects
  stay private and are served via short-lived signed URLs.
- The upload also validates type (JPG/PNG/WEBP) and size (≤12MB) client-side; the
  backend re-validates the content type on `POST /v1/admin/media/presign`.

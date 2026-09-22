# StyloAI — External Setup Guide (mobile-phone friendly)

Follow these in order. Each step says what to tap and **which value goes where**.
Secrets live in one of four places only — never in code, never in chat:

- **Server `.env`** on your EC2 box (backend secrets)
- **GitHub → Settings → Secrets and variables → Actions** (build secrets)
- **A provider console** (Firebase / AWS / Play)
- **The repo, non-secret config only** (`firebase_options.dart`, `google-services.json`)

📱 **Phone tips**
- In your mobile browser, use **"Request desktop site"** for the AWS, Play, and
  GitHub consoles.
- Install a browser-based shell (**Google Cloud Shell**, free) for the few
  `keytool` / `ssh` commands — no PC needed.
- Install an SSH app (**Termius**) to configure the EC2 server.

Package name used everywhere: **`app.stylo.styloai`**
Credit product IDs used everywhere: **`credits_50`, `credits_120`, `credits_300`**

---

## 1. Firebase (Auth + Cloud Messaging)

1. Open **console.firebase.google.com** → **Add project** → name it `StyloAI` →
   create (Analytics optional).
2. **Add an Android app**: project overview → the Android icon →
   **Android package name** = `app.stylo.styloai` → register.
3. **Download `google-services.json`.** Put it in the repo at
   **`mobile/android/app/google-services.json`** (GitHub web → that folder →
   Add file → Upload). It's client config, not a secret.
4. **Authentication → Get started → Sign-in method → Google → Enable → Save.**
5. **Fill the app's Firebase options** so the app knows it's configured. Open
   `mobile/lib/core/firebase_options.dart` in GitHub's web editor and replace the
   5 placeholder values from `google-services.json`:
   | firebase_options.dart | value in google-services.json |
   |---|---|
   | `apiKey` | `client[0].api_key[0].current_key` |
   | `appId` | `client[0].client_info.mobilesdk_app_id` |
   | `messagingSenderId` | `project_info.project_number` |
   | `projectId` | `project_info.project_id` |
   | `storageBucket` | `project_info.storage_bucket` |
   Commit. (This flips the app out of "sign-in setup required".)
6. **Service account for the backend**: **Project settings (gear) → Service
   accounts → Generate new private key** → downloads a JSON file.
   - Its whole contents → backend `.env` as **`FIREBASE_SERVICE_ACCOUNT_JSON`**
     (one line; used for verifying sign-ins and sending push).
   - Project settings → General → **Project ID** → backend `.env`
     **`FIREBASE_PROJECT_ID`**.
7. **SHA-1 fingerprints** (required for Google sign-in to work). You'll add these
   in step 6-Play after your first upload — come back and: **Project settings →
   your Android app → Add fingerprint** → paste the **App signing** and **Upload**
   SHA-1 from Play Console. (Until then, sign-in works only on debug builds.)

---

## 2. Gemini (AI image generation)

1. Open **aistudio.google.com** → **Get API key** → **Create API key** (choose or
   create a Google Cloud project). Image generation needs billing enabled on that
   Cloud project.
2. The key → backend `.env` as **`GEMINI_API_KEY`** (server only — it must never
   be in the app).
3. Set **`GEMINI_MODEL`** in `.env` to the current image-capable Gemini model
   (e.g. `gemini-2.0-flash-preview-image-generation`). If a generation later
   returns "no image", switch this to whatever image-output Gemini model your key
   has access to — it's the one value to adjust, nothing else changes.

---

## 3. AWS — S3 (image storage)

1. **console.aws.amazon.com → S3 → Create bucket.** Name e.g. `stylo-media`,
   pick a region (remember it), **Block all public access = ON**, create.
   - Bucket name → backend `.env` **`S3_BUCKET`**; region → **`AWS_REGION`**.
2. **Bucket → Permissions → CORS** → paste (lets the admin panel upload images):
   ```json
   [{"AllowedHeaders":["*"],"AllowedMethods":["PUT","GET"],
     "AllowedOrigins":["https://admin.yourdomain.com"],"ExposeHeaders":[]}]
   ```
   (Change the origin once you have your domain in step 5. The mobile app doesn't
   need CORS — only the browser admin does.)

## 3b. AWS — RDS PostgreSQL (database)

1. **RDS → Create database → PostgreSQL** → **Free tier / db.t4g.micro** →
   set **DB instance identifier**, **master username**, **master password**,
   **initial database name** (e.g. `stylo`). Create.
2. Wait for it, then open it → copy the **Endpoint**.
3. Build the connection string → backend `.env` **`DATABASE_URL`**:
   `postgresql://<user>:<password>@<endpoint>:5432/<dbname>?schema=public`
   (type it into the server `.env`, not here).
4. **Connectivity**: RDS **security group → inbound rule → PostgreSQL (5432)** from
   your **EC2 instance's security group** (added in step 4).

## 3c. AWS — IAM role for the server (no static keys)

1. **IAM → Roles → Create role → AWS service → EC2.**
2. Attach a policy granting S3 access to your bucket (start with
   `AmazonS3FullAccess`, tighten to the bucket later). Name it `stylo-ec2-role`,
   create. You'll attach it to EC2 in step 4 — then the server needs **no** AWS
   keys in `.env`.

---

## 4. AWS — EC2 (the backend server) + Redis

1. **EC2 → Launch instance**: Ubuntu 22.04, **t3.small**, create/download a key
   pair (store it in Termius). **Security group inbound**: SSH 22 (your IP),
   HTTP 80, HTTPS 443. Launch. Then **Elastic IP → allocate → associate** to the
   instance (a stable IP for DNS).
2. **Attach the IAM role**: instance → **Actions → Security → Modify IAM role →**
   `stylo-ec2-role`.
3. Add this instance's **security group** to the RDS inbound rule (step 3b-4).
4. **SSH in with Termius** and run:
   ```bash
   curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
   sudo apt-get install -y nodejs git redis-server
   sudo systemctl enable --now redis-server
   git clone https://github.com/SouvikPati11/StyloAI.git && cd StyloAI/backend
   npm ci
   ```
   Redis on the box → backend `.env` **`REDIS_URL=redis://localhost:6379`**.
5. **Create the server `.env`**: `cp .env.example .env` then edit `.env` with a
   terminal editor (`nano .env`) and fill every value from the steps above:
   `DATABASE_URL`, `REDIS_URL`, `JWT_ACCESS_SECRET`, `JWT_REFRESH_SECRET`
   (make these long random strings), `FIREBASE_PROJECT_ID`,
   `FIREBASE_SERVICE_ACCOUNT_JSON`, `GEMINI_API_KEY`, `GEMINI_MODEL`,
   `AWS_REGION`, `S3_BUCKET`, `PLAY_PACKAGE_NAME=app.stylo.styloai`,
   `ADMIN_BOOTSTRAP_EMAIL`, `ADMIN_BOOTSTRAP_PASSWORD`. (Play + domain values come
   in steps 5–6.)
6. **Migrate, seed, run**:
   ```bash
   npx prisma migrate deploy
   npm run seed          # credit costs, categories, store products, first admin
   npm run build
   sudo npm i -g pm2 && pm2 start dist/main.js --name stylo-api && pm2 save
   ```
   The API now listens on port 3000 on the box.

---

## 5. Domain + HTTPS (api. and admin.)

1. In your DNS (Route 53 or your registrar): create **A records**
   `api.yourdomain.com` and `admin.yourdomain.com` → your EC2 **Elastic IP**.
2. On EC2 (Termius), put Nginx in front and get free TLS:
   ```bash
   sudo apt-get install -y nginx certbot python3-certbot-nginx
   ```
   Create `/etc/nginx/sites-available/stylo` with two server blocks proxying
   `api.yourdomain.com` and `admin.yourdomain.com` → `http://localhost:3000`,
   enable it, then:
   ```bash
   sudo certbot --nginx -d api.yourdomain.com -d admin.yourdomain.com
   ```
   Certbot installs HTTPS automatically. (Alternative with no SSH: an
   Application Load Balancer + an ACM certificate.)
3. Update backend `.env` and restart (`pm2 restart stylo-api`):
   - `API_BASE_URL=https://api.yourdomain.com`
   - `ADMIN_BASE_URL=https://admin.yourdomain.com`
   - `CORS_ALLOWED_ORIGINS=https://admin.yourdomain.com`
4. Update the **S3 bucket CORS** origin (step 3-2) to
   `https://admin.yourdomain.com`.
5. The **admin panel** is now at **`https://admin.yourdomain.com/admin`** — log in
   with the `ADMIN_BOOTSTRAP_EMAIL` / `ADMIN_BOOTSTRAP_PASSWORD` you seeded.

---

## 6. Google Play Console + Billing

1. **play.google.com/console → Create app.** App name **StyloAI**, app, free,
   accept policies. (One-time $25 developer registration.)
2. **Create the app's package**: complete the **Store listing** basics and, under
   **Test and release → Testing → Internal testing**, create a release later
   (step 7). The applicationId is `app.stylo.styloai`.
3. **Play App Signing**: it's on by default. After your first AAB upload (step 7),
   go to **Test and release → App integrity → App signing** and copy both the
   **App signing key certificate SHA-1** and the **Upload key certificate SHA-1**
   → add both in **Firebase → Project settings → your Android app → Add
   fingerprint** (this is what makes Google sign-in work in release builds).
4. **In-app products** (credits): **Monetize → Products → In-app products →
   Create product** three times, as **consumable**, with IDs exactly
   `credits_50`, `credits_120`, `credits_300`, priced how you like, activated.
   (They must match the backend `store_products` seed.)
5. **Server-side purchase verification** — enable the Play Developer API:
   - **Play Console → Users and permissions → (link a Google Cloud project) →**
     and in **Google Cloud Console → APIs & Services → Enable APIs →
     "Google Play Android Developer API".**
   - **Create a service account** (Cloud Console → IAM → Service accounts) →
     create a JSON key → then in **Play Console → Users and permissions → Invite**
     that service account with **View financial data / manage orders** (or the
     API-access grant).
   - The service-account JSON → backend `.env` **`PLAY_SERVICE_ACCOUNT_JSON`**;
     confirm **`PLAY_PACKAGE_NAME=app.stylo.styloai`**. Restart `pm2 restart
     stylo-api`. (Until this is set, the app shows a clean "purchases not enabled
     yet" message — it never fakes a purchase.)
6. **License testers**: **Setup → License testing** → add your Google account so
   you can test purchases without being charged.

---

## 7. GitHub Actions (build the signed app)

1. **Generate an upload keystore** in **Google Cloud Shell** (browser, phone-ok):
   ```bash
   keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 \
     -validity 10000 -alias upload
   base64 -w0 upload-keystore.jks > keystore.b64
   ```
   Answer the prompts; **remember the store password, key password, and alias**.
   Download `upload-keystore.jks` somewhere safe (offline backup) and open
   `keystore.b64` to copy its text.
2. **GitHub → your repo → Settings → Secrets and variables → Actions → New
   repository secret** — add these (paste values here, never in chat):
   | Secret | Value |
   |---|---|
   | `ANDROID_KEYSTORE_BASE64` | contents of `keystore.b64` |
   | `ANDROID_KEYSTORE_PASSWORD` | the store password |
   | `ANDROID_KEY_PASSWORD` | the key password |
   | `ANDROID_KEY_ALIAS` | `upload` |
   | `PROD_API_BASE_URL` | `https://api.yourdomain.com` |
   | `PLAY_SERVICE_ACCOUNT_JSON` | *(optional)* for auto-publish to Play |
3. **Build**: create a tag to trigger the release workflow. From the GitHub mobile
   site: **Releases → Draft a new release → tag `v1.0.0` → Publish**, or push a
   tag. The **`android_release`** workflow runs `flutter analyze/test`, builds a
   **signed AAB + APK**, and uploads them under the run's **Artifacts**.
4. **Upload to Play**: download the `.aab` artifact → **Play Console → Internal
   testing → Create release → upload the AAB → roll out.** Then do step 6-3
   (copy the SHA-1s into Firebase). Install via the internal-testing link on your
   phone.

---

## Production smoke-test checklist

Run these after setup, in order. ✅ each before moving on.

**Backend / infra**
- [ ] `https://api.yourdomain.com/v1/health` returns `{"status":"ok","db":"ok"}`.
- [ ] `https://api.yourdomain.com/v1/config` returns credit_costs + features.
- [ ] `pm2 logs stylo-api` shows "Prisma connected" and no "not configured"
      warnings for Firebase / Gemini / Play (once you've set them).

**Admin panel** (`https://admin.yourdomain.com/admin`)
- [ ] Log in with the bootstrap admin.
- [ ] Dashboard shows real counts (users/generations).
- [ ] **Content → Add** a trending item with an image upload → it saves and the
      image thumbnail loads.
- [ ] **Settings** → edit a `credit_costs` value → Save (the app will pick it up).

**App — auth & home** (internal-testing build on a real phone)
- [ ] Onboarding shows; **Continue with Google** signs in (no "setup required"
      screen). If it errors, re-check the SHA-1s in Firebase (step 6-3).
- [ ] Home shows your name, a **credit balance** (the signup bonus), and the
      trending item you added in admin.

**App — the core generation flow**
- [ ] Create → **Outfit** → add your photo → pick a style → **Generate** → the
      progress screen shows, then a **result image** appears.
- [ ] Your **credit balance dropped** by the outfit cost (check Credits → history
      shows a "Generation" entry). This proves server-side deduction.
- [ ] The result looks like **you** with a changed outfit (identity preserved).
- [ ] **Upload reference** mode: Outfit/Hair/Glasses → upload a reference image →
      generate → the reference's style is applied to you.
- [ ] **Save look** → it appears under **Looks → Saved**; the generation appears
      under **Looks → History**.

**App — credits & billing**
- [ ] Credits screen lists the three packs.
- [ ] As a **license tester**, buy a pack → after a moment your **balance
      increases** and history shows a **"Credits purchased"** entry (this is the
      server-verified grant; a fake client "success" would not add credits).

**App — failure & limits (optional but recommended)**
- [ ] Spend down to below a generation's cost → starting a generation shows the
      **"Not enough credits"** sheet routing to the store.
- [ ] If a generation ever fails, history shows **"Failed — refunded"** and the
      credits return.

**App — engagement, profile, privacy**
- [ ] Generation-complete **push notification** arrives (background the app during
      a generation). Requires the Firebase service account set on the backend.
- [ ] **Style preferences** save; **recommendations** reflect them.
- [ ] **Settings** → toggle a notification pref; open **Privacy Policy** and
      **Terms**; **Delete account** on a throwaway account removes it.

**Security spot-checks**
- [ ] The app package contains **no** Gemini/AWS/DB/Play keys (they're all
      server-side). `git grep` the repo finds no real secret values.
- [ ] Hitting `POST /v1/generations` without a valid token returns
      `UNAUTHENTICATED`.

When every box is checked, StyloAI is functioning end-to-end in production.

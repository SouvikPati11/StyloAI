# StyloAI — Flutter App: Screen Map & Design System

A premium, fashion-forward, AI-native Android app. Not a dashboard-in-a-phone.
Restrained: no excessive gradients/glassmorphism, purposeful motion, real copy.

---

## 1. Navigation

**Bottom navigation — 5 destinations:**

| Tab | Purpose |
|-----|---------|
| **Home** | Personalized entry, primary CTA, quick actions, trending, recent |
| **Explore** | Trending outfits/hair/glasses/AI edits/poses + inspiration (§6) |
| **Create** | The 6 generation flows (Outfit, Hair, Glasses, Accessories, Pose, AI Edit) |
| **Looks** | My Looks, Saved Looks, Generation History (§19) |
| **Profile** | Avatar, credits, style preferences, settings, privacy/terms, logout |

Routing via **go_router** (deep links for FCM taps → generation result). Modal,
full-screen flows for generation; results push onto a shared Result screen.

---

## 2. Screen map

```
Onboarding
  ├─ Splash
  ├─ Intro carousel (Discover style · Try outfits · Hair · Glasses · Create AI looks · Trends)
  └─ Google Sign-In  →  (first run) Set base photo + optional Style Profile

Home
  ├─ Greeting + credit balance chip
  ├─ Primary CTA: "Improve My Look"
  ├─ Quick Create row (Outfit · Hair · Glasses · AI Edit)
  ├─ Trending styles carousel
  ├─ Recommended for you (from Style Profile)
  └─ Recent creations

Explore (Trending)
  ├─ Section tabs: Outfits · Hair · Glasses · AI Edits · Poses · Inspiration
  └─ Content grid (DB-driven, admin-managed) → tap → "Try this"

Create (hub → 6 flows)
  Each flow: Pick/confirm your photo →
    ├─ Explore Styles (category chips + preset grid)   OR
    └─ Upload Reference (outfit/hair/glasses image)
    → Review (cost shown from /config) → Generate →
    → Processing (honest progress messaging) → Result

Result
  ├─ Before/After presentation
  ├─ Save to Looks · Share (roadmap) · Regenerate · Download
  └─ Credit balance updated from server

Looks
  ├─ My Looks · Saved · History (filter by type)
  └─ Detail → manage/delete (privacy)

Credits / Store
  ├─ Balance + ledger history
  └─ Credit packs (Play Billing) → server-verified grant

Profile
  ├─ Avatar, name, credits
  ├─ Style Preferences (user vs AI-suggested, labeled)
  ├─ Notification settings, Privacy, Terms
  └─ Account (delete data / account), Logout
```

---

## 3. Generation flow states (§26)
Every flow explicitly handles: `idle → capturing → uploading → submitting →
queued → processing → success | failed | insufficient_credits | rate_limited |
auth_error | network_error`. Processing shows honest messaging (no fake exact
percentages when the API doesn't provide them). Insufficient credits routes to
the Store. Failures offer Retry and confirm any refund.

---

## 4. Design system

**Direction:** editorial, calm, premium. Content (the user's photos/looks) is
the hero; UI recedes.

### Tokens
- **Color:** near-black ink `#141414` on warm off-white `#FAF8F5`; a single
  restrained accent (deep plum/terracotta) for the primary CTA; muted neutrals
  for surfaces; semantic success/warn/error. Full dark theme (near-black
  surfaces, off-white ink). Defined once as `AppColors`.
- **Typography:** an elegant display face for headings (e.g. a refined serif or
  a high-quality grotesk) + a clean sans for body; a small, deliberate type
  scale. `AppTextStyles`.
- **Spacing:** 4-pt base scale (4/8/12/16/24/32). Generous whitespace.
- **Shape:** soft-but-restrained radii (12–16), subtle elevation, no heavy
  shadows. `AppRadii`, `AppShadows`.
- **Motion:** short, eased transitions; a considered generation/reveal animation
  for the before/after. No gratuitous animation.

### Reusable components (built once, in `mobile/lib/design/`)
`StyloScaffold`, `PrimaryButton`/`SecondaryButton`, `CreditChip`, `SectionHeader`,
`StyleCard`, `CategoryChip`, `PhotoPicker`, `ReferenceUploader`, `ResultView`
(before/after), `EmptyState`, `LoadingState`, `ErrorState`,
`InsufficientCreditsSheet`, `CostBadge` (renders cost from `/config`).

### States, everywhere
Coherent empty / loading / error states as first-class components — never a bare
spinner or blank screen.

---

## 5. App architecture (Flutter)
```
mobile/lib/
  app/            # bootstrap, router (go_router), theme
  design/         # tokens + reusable components (design system)
  core/           # env, dio client (auth interceptor), error mapping, result types
  features/
    onboarding/  auth/  home/  explore/  create/  result/
    looks/  credits/  profile/  style_profile/
  data/           # api clients, dtos, repositories
  state/          # Riverpod providers/notifiers
```
- **State:** Riverpod (async generation notifiers, auth state, wallet).
- **Networking:** Dio + interceptor (attach JWT, refresh on 401, retry idempotent
  requests). - **No secrets in app:** only the API base URL, Firebase client
  config (`google-services.json`, which is *not* a secret but is gitignored per
  convention), and public product ids.

### Config injection
Base URL and flavor via `--dart-define` at build time (dev/staging/prod). Credit
costs, features, categories all come from `GET /config` at runtime.

---

## 6. Copy
All strings are real product copy (no "Lorem ipsum"/"Feature 1"). Primary CTA:
**"Improve My Look."** Tone: confident, warm, stylist-like, concise.

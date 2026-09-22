# StyloAI — Credits & Billing

The credit economy is **server-authoritative** and built on an append-only
ledger. Google Play purchases are **verified server-side** before any credit is
granted. The Flutter app never computes balances, never decides costs, and its
"purchase successful" signal is never trusted on its own.

---

## 1. Credit model

- **Wallet** (`credit_wallets`): cached integer balance per user.
- **Ledger** (`credit_transactions`): append-only, signed amounts, authoritative.
- Balance changes **only** inside a DB transaction that appends a ledger row and
  sets `balance_after`. A `CHECK (balance >= 0)` is the DB backstop.

### Credit costs
Costs live in `system_settings.credit_costs` (DB), editable from the admin
panel — **never hard-coded in Flutter**. The app fetches them from `GET /config`
and renders them. Example (admin-editable) values:

| Generation | Example cost |
|------------|--------------|
| outfit | 4 |
| hair | 4 |
| glasses | 2 |
| accessories | 2 |
| pose | 1 |
| ai_edit | 3 |

### Sources of credits
`signup_bonus`, `admin_grant`, `promo`, `purchase`. New users get
`signup_bonus_credits` (settings) on first `/auth/google`.

---

## 2. Spend lifecycle (hold → settle/refund)

Two-phase to protect against paying for failed AI work:

1. **Hold** — on `POST /generations`, in one transaction: insert
   `generation_hold` (`amount = -cost`, `status='pending'`), decrement wallet,
   create the `generations` row. Reject up front if `balance < cost`
   (`INSUFFICIENT_CREDITS`).
2. **Settle** — on success, mark the hold `committed`
   (type stays a spend; the credits are consumed). No balance change (already
   deducted at hold).
3. **Refund** — on eligible failure, `reverse` the hold: insert a compensating
   `generation_refund` (`amount = +cost`, links same `generation_id`), restore
   wallet, set generation `status='refunded'`.

**Refund policy (eligible failures):** provider/internal errors, timeouts,
safety rejections not caused by user misuse. **Not refunded:** a *successful*
generation the user simply dislikes. Policy encoded server-side, logged, and
visible in the ledger.

Idempotency: the `generation_hold` and refund each carry an `idempotency_key`
so a retried worker or retried submit never double-charges or double-refunds.

---

## 3. Google Play Billing flow

```
Flutter (in_app_purchase)                Backend                    Google Play
──────────────────────────               ───────                    ───────────
1. Query products (store UI) ◄── /store/products
2. Launch purchase ─────────────────────────────────────────────► Play sheet
3. Purchase completes → purchaseToken
4. POST /billing/google/verify ─────────► 5. Verify token via
   {product_id, purchase_token,             Play Developer API
    order_id}                                (purchases.products.get)
                                          6. Check state=purchased,
                                             not already consumed,
                                             product_id matches
                                          7. Acknowledge purchase
                                          8. In one DB txn:
                                             - insert purchases (token UNIQUE)
                                             - insert `purchase` ledger row
                                             - increment wallet
9. res {granted, credits_added, balance}◄─┘
10. App refreshes wallet from server (not from local state)
```

**Guarantees**
- `purchases.purchase_token` is **UNIQUE** → a token can grant credits at most
  once, even under retries/replays.
- Backend **acknowledges** the purchase within Google's window (else auto-refund).
- Verification uses a Google service account with the **Play Developer API**;
  its credentials are a **backend secret** (never in the app).
- Client-reported success alone grants nothing — only server verification does.

**Failure/edge handling**
- Pending purchases: store `state='pending'`, poll/verify later; grant on
  confirmation. - Verify failures → `PAYMENT_INVALID`, no grant, purchase row
  `state='invalid'`, logged for review. - Deferred grants survive app restarts
  because the token→grant record is server-side.

---

## 4. Future expansion (designed for, not built in MVP)
- **Multiple credit packs**: rows in `store/products` + Play console products.
- **Subscriptions**: add `subscriptions` table + Play RTDN (Real-time
  Developer Notifications) webhook to `/billing/google/rtdn` for renewals,
  cancellations, refunds; grant monthly credits on renewal events.
- **Promo credits**: `promo` ledger type, admin-issued or code-redeemed.

The ledger + verification design already accommodates these without schema
rewrites.

---

## 5. What the client is trusted for
**Nothing financial.** It displays server data, initiates the Play purchase UI,
and forwards the purchase token. Every balance shown is the last value returned
by the server; after any generation or purchase the app re-reads `/wallet`.

# Supabase Security Architecture & Threat Model

Toolbox PRO operates in a "backendless" architecture where the browser interacts directly with Supabase. Security is therefore entirely enforced at the database layer using PostgreSQL constraints and Row Level Security (RLS).

## Implemented Protections

### 1. Zero Trust Frontend
The frontend JavaScript is treated as an untrusted client. 
- The frontend **cannot** alter a user's subscription plan (Entitlements table).
- The frontend **cannot** dictate the `user_id` when inserting conversion history or AI usage. All `user_id` inserts are validated against `auth.uid()` via RLS `WITH CHECK`.

### 2. IDOR / BOLA Prevention (Row Level Security)
Insecure Direct Object Reference (IDOR) is prevented using RLS. 
- Even if User A attempts to query `SELECT * FROM conversion_history WHERE user_id = 'USER_B_ID'`, the database will return `0 rows` because the RLS policy explicitly enforces `USING (auth.uid() = user_id)`.
- This applies to profiles, entitlements, history, and usage tables.

### 3. Protected Secrets
- The `service_role` key (which bypasses all RLS) is **never** exposed to the browser.
- Future AI API keys (like OpenAI) must remain completely out of the browser. These will be securely stored in Supabase Secrets and accessed only via Supabase Edge Functions.

### 4. Storage Isolation
- The `user_files` bucket is strictly private.
- The storage RLS policy enforces that a user can only read, write, or delete files if the root folder name matches their verified Supabase `auth.uid()`. Cross-user file access is mathematically impossible at the database level.

### 5. Anonymous Usage Constraints
- Unauthenticated users cannot read or write to any tracked tables (`profiles`, `conversion_history`, etc.).
- Basic file conversion remains on the browser, preventing server memory exhaustion or unauthenticated DDOS attacks on the API.

## Remaining Risks & Future Improvements

1. **AI Usage Spoofing (Edge Functions Required):**
   - Currently, AI usage is a planned feature. When implemented, AI tracking must **not** be driven by the frontend reporting "I used 50 tokens."
   - *Fix:* AI requests must go through a Supabase Edge Function which securely validates the session, executes the OpenAI request using a hidden backend key, logs the exact tokens consumed to the `ai_usage` table (using the service role key), and then returns the result to the browser.

2. **Entitlement Upgrades:**
   - The frontend cannot upgrade a user to "Pro".
   - *Fix:* When Stripe/payment is integrated, a Supabase Edge Function acting as a Stripe Webhook receiver must be used to securely receive the payment confirmation and update the `entitlements` table.

3. **Rate Limiting:**
   - While Supabase Auth has built-in rate limits for login/signup, the application does not currently rate-limit how many files an authenticated user can convert in the browser. 
   - *Fix:* Because processing is strictly client-side (CPU bound to the user's device), this is a low-risk vector for server infrastructure, but may affect analytics billing.

## Conclusion
The architecture adheres to the principle of least privilege. Data access boundaries are tightly coupled to verified cryptographic sessions (JWTs) via PostgreSQL Row Level Security.

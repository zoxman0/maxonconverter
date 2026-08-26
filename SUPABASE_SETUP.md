# Supabase Configuration & Setup Guide

This document outlines the steps required to fully configure Supabase for Toolbox PRO. Because this application operates strictly without a traditional backend (Node.js/Python), we rely entirely on the Supabase PostgreSQL database, Row Level Security (RLS), and Edge Functions to maintain security.

## 1. Project Configuration
1. Create a new project in the [Supabase Dashboard](https://supabase.com/dashboard).
2. Note your **Project URL** and **Anon/Public Key** from `Project Settings -> API`.
3. Rename the `.env.example` file in your local repository to `.env` (if using a build step) or update `js/config/env.js` directly with these credentials.
   > **Note on Client-Side Keys:** The Supabase Anon key is safe to expose in Vanilla JS *only if* Row Level Security (RLS) is strictly enforced in the database.

## 2. Database Schema & RLS Setup
1. Navigate to the **SQL Editor** in your Supabase Dashboard.
2. Open the file `supabase_setup.sql` provided in this repository.
3. Paste the contents into the SQL Editor and click **Run**.
4. This script automatically provisions:
   - `profiles` table
   - `entitlements` table (Free/Pro plans)
   - `conversion_history` table
   - `ai_usage` table
   - A `handle_new_user` trigger that fires on sign-up to create the user's default `free` profile.
   - Comprehensive **Row Level Security (RLS)** policies that lock down data to the authenticated user ID.

## 3. Storage Buckets (Optional)
If you wish to enable the "Save to Account" feature:
1. Navigate to **Storage** in the Supabase Dashboard.
2. Create a new bucket named `user_files`.
3. Set the bucket to **Private** (Do not enable "Public" access).
4. Run the storage RLS policies located at the bottom of the `supabase_setup.sql` script to ensure users can only upload and read files within their own `user_id/` subfolder.

## 4. Authentication Configuration
1. Navigate to **Authentication -> Providers** in the Supabase Dashboard.
2. Ensure **Email** is enabled.
3. (Optional) Disable "Confirm Email" if you want frictionless signups during development.
4. **Google Login Setup:**
   - Go to Google Cloud Console and create a new project.
   - Configure the OAuth Consent Screen.
   - Go to Credentials -> Create Credentials -> OAuth client ID.
   - Choose "Web application".
   - Set the Authorized Redirect URI to your Supabase callback URL (found in the Supabase Dashboard under Providers -> Google).
   - Copy the Client ID and Client Secret.
   - Back in Supabase Dashboard -> Providers -> Google, toggle it ON and paste your Client ID and Secret.

## 5. Local Development
Because we are using Vanilla JS:
- You can simply serve the directory using any static server (e.g. `npx serve .` or VS Code Live Server).
- Authentication works immediately over localhost.
- Check the browser console to verify `[Supabase] Initialized`.

## 6. Production Deployment
1. When deploying to production (e.g. Cloudflare Pages, Vercel, Netlify), ensure your web server routes all 404 traffic to `index.html`. This ensures the HTML5 History API clean URLs (`/dashboard`, `/login`) resolve correctly.
2. In `js/config/env.js`, set `IS_PRODUCTION: true`.
3. Go to **Authentication -> URL Configuration** in Supabase and add your production domain to the **Site URL** and **Redirect URLs** list.

# Apna Parivaar – Digital Family Management System

A single-page web app using Supabase Auth + Database + Edge Functions. Frontend is pure HTML + Tailwind + Supabase JS. No backend server.

## Features
- Email/password auth with role and family metadata
- Roles: Super Admin, Family Admin, Sub Admin, Member
- Family and member management (RLS policies enforce access)
- Payment flow that emails a UPI QR code via Resend (Edge Function)
- Family tree visualization (vis-network)
- Light/Dark theme toggle

## Prerequisites
- Supabase project URL and anon key
- Supabase CLI installed (`npm i -g supabase`)
- Resend API key

## Setup

1) Create schema, RLS and policies

- Open Supabase SQL editor and run the contents of `supabase/sql/schema.sql`.

2) Configure Edge Function

- Create function directory structure:

```
supabase/functions/send_qr_email/index.ts
```

- The code is already provided in this repo at `supabase/functions/send_qr_email/index.ts`.

3) Set secrets for the Edge Function

Replace YOUR_SERVICE_ROLE_KEY with the provided service role key.

```
supabase secrets set SUPABASE_URL=https://yfwvmxsvpsivralwwlww.supabase.co
supabase secrets set SUPABASE_SERVICE_ROLE=YOUR_SERVICE_ROLE_KEY
supabase secrets set RESEND_API_KEY=re_USxDRnB4_FZEgzgzX9pYnxG8dkNSj32Ls
```

4) Deploy the Edge Function

```
supabase functions deploy send_qr_email --project-ref yfwvmxsvpsivralwwlww --no-verify-jwt
```

5) Frontend configuration

- Open `index.html` and set these constants near the top of the script:
  - `SUPABASE_ANON_KEY` – paste your project anon key
  - `UPI_QR_URL` – use a publicly accessible image URL (e.g., upload to Supabase Storage with public bucket and use the public URL)

6) Local preview (optional)

You can serve `index.html` with any static server (e.g., VS Code Live Server) or just open it directly in a browser.

## Usage
- Signup: choose role and family name. A `profiles` row is created and a `families` row auto-creates via trigger.
- Family Admin & Sub Admin can manage members.
- Super Admin can list all Family Admins and view all payments.
- Family Admin can click “Pay ₹500” to trigger an email with the QR code.

## Notes
- RLS policies check `profiles.role` and `profiles.family_name`. Ensure `profiles` is created for each user (this app upserts after signup/login).
- For production, configure email templates and verified sender in Resend.
- If you change table names or roles, update policies and frontend.



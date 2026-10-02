# El Saidy Travel · Suez–Galala Bus Reservation

A responsive Arabic-first PWA for student transportation reservations between Suez and Galala.

## Implemented

- React + TypeScript + Vite + Tailwind CSS + React Router + Lucide icons.
- Arabic RTL default and English LTR switcher with a light-only, mobile-first visual system.
- Installable PWA manifest, branded icons, service worker, safe-area/mobile layout, and private-data-safe caching.
- Supabase Auth integration with student registration/login/session recovery.
- Pending → approved/rejected/suspended account flow with protected student ID/role/status rules.
- Student dashboard, profile, subscription progress, notifications, booking history, cancellation, and transactional booking wizard.
- One booking per student per day and trip-capacity protection in the Supabase migration/RPC layer.
- Admin dashboard, live student review, subscription management, clickable station groups with student details and call links, status actions, station and departure-time management, CSV export, print view, and security-alert review.
- Registration captures each student's usual travel weekdays. Selecting a date outside that schedule creates a company-review request; admins can approve or reject it from `/admin/requests`.
- Supabase API integration is part of the application: `src/lib/api.ts` contains the student/admin data services and `src/lib/supabase.ts` creates the browser client from `import.meta.env`.
- Dynamic booking hours are managed from `/admin/booking-hours`; administrator active/blocked status is managed from `/admin/admins` with protected RPCs and audit logs.
- Migration `0005_student_schedule_requests.sql` adds `profiles.preferred_weekdays`, `booking_change_requests`, RLS, and the secure request/review RPCs.
- Migration `0006_security_events_and_rate_limits.sql` adds protected security events, progressive temporary blocks, admin alerts, database write guards, and least-privilege grants.
- 29 requested stations and the `09:00` departure seed.
- Exact footer: `Developed by Eslam Samir | 01033009276`.
- El Saidy Travel uses the clean transparent mark at `public/branding/saidy-mark.svg`; the old rectangular reference image remains only as an unused source asset. Auth and the authenticated shell use a neutral iOS-inspired light/dark visual system with safe-area mobile navigation.

When Supabase environment variables are absent, the Preview can be explored using the clearly labeled local Preview Mode shortcuts. No Preview Mode operation is presented as production data.

## Run locally

```bash
npm install
cp .env.example .env
# edit .env: VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY
npm run dev
```

Open `http://localhost:3000`.

Checks:

```bash
npm run typecheck
npm run build
```

## Database

Apply the ordered SQL migrations in `supabase/migrations/` from the Supabase SQL Editor. See [`supabase/README.md`](./supabase/README.md) for exact setup, Auth configuration, first-admin SQL, security notes, and operational defaults.

### Main tables

`profiles`, `student_registry`, `stations`, `subscriptions`, `departure_times`, `trips`, `bookings`, `notifications`, `admin_settings`, and `audit_logs`.

Apply migrations in numeric order through `0008_booking_hours_and_admin_accounts.sql`. The latest migration adds database-enforced booking hours, active/blocked administrator status, self/last-admin protection, and audit logging.

### Security rules

RLS is enabled on every application table. Students only read their own profile/subscription/bookings/notifications plus active reference data. Admin/staff access is checked with security-definer role helpers. Booking creation, duplicate-date rejection, subscription checks, cancellation cutoff, capacity locks, protected booking/profile fields, progressive abuse scoring, temporary blocks, and admin alerts are enforced by database functions/triggers and indexes rather than frontend validation alone. Supabase Auth provider limits remain authoritative for login, signup, and reset endpoints; see `supabase/README.md` for the exact boundary.

## Deployment

Build output is `dist/`. Configure the static host for:

- immutable cache for hashed assets under `dist/assets/`
- no-cache or short-lived cache for `index.html`
- SPA fallback for the browser routes listed in `route-manifest.json`
- no shared caching of Supabase/private API responses

The app expects only the public Supabase URL and anon/publishable key in frontend environment variables. The root `.env` is ignored by Git; keep real values out of `.env.example` and never add a service-role credential to `.env` or client code.

# Supabase setup

## Apply migrations

1. Create a Supabase project.
2. In Supabase Dashboard → SQL Editor, run the files in lexical order:
   - `migrations/0001_initial_schema.sql`
   - `migrations/0002_security_functions.sql`
	   - `migrations/0003_rls_policies.sql`
	   - `migrations/0004_seed_data.sql`
	   - `migrations/0005_student_schedule_requests.sql`
	   - `migrations/0006_security_events_and_rate_limits.sql`
3. In Authentication → Providers, enable Email and decide whether email confirmation is required. Keep email confirmation enabled for production if the company can deliver confirmation messages.
4. Copy the project URL and the public anon key into the app environment as `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY`. Never put a service-role key in the frontend.

The application starts new users as `pending`; email confirmation is an additional gate, not a replacement for company approval.

## Create the first admin

1. Register the first account through the app or create it in Supabase Authentication → Users.
2. Copy that user’s UUID.
3. Run the following SQL in the Supabase SQL Editor as the project owner (or another trusted SQL session). Do not expose this capability through the public app:

```sql
update public.profiles
set role = 'admin',
    account_status = 'approved',
    approved_at = now()
where id = 'PASTE_AUTH_USER_UUID_HERE';
```

4. Sign in again. The user will receive the admin dashboard. Every later admin mutation is protected by `is_admin_or_staff()` and recorded in `audit_logs` where applicable.

## Operational defaults

- 29 stations are seeded in the requested order.
- `09:00` is the seeded departure time.
- New trips default to capacity `40`.
- Student cancellation closes `4` hours before departure.
- Booking horizon is `30` days.
- These values are stored in `admin_settings`, not hardcoded into the UI, and can be changed by an authorized administrator through SQL until the settings screen is connected to a dedicated admin-settings RPC.

## Security notes

- RLS is enabled on all application tables.
- Students can read only their own profile, subscription, bookings, and notifications, plus active booking reference data.
- The critical one-booking-per-student-per-day rule is a partial unique index and is also checked inside the transactional `create_booking_batch` function.
- Trip capacity is protected by row locking inside `create_booking_batch`; a full trip returns `BOOKING_CAPACITY_FULL`.
- Profile triggers prevent students from changing role, account status, approval metadata, or approved Student ID.
- Admin and staff access is checked in security-definer functions; no client-side role check is trusted as authorization.
- Migration `0006_security_events_and_rate_limits.sql` adds `security_events` and `security_principals`, progressive score-based warnings/rate limits, temporary blocks, admin alerts, protected booking/request/profile triggers, least-privilege grants, and an admin security-review screen.
- Booking writes, cancellations, off-schedule requests, protected profile updates, station/time/settings writes, and admin subscription edits are guarded in the database. Students cannot directly mutate subscriptions, roles, approval fields, bookings, trips, station definitions, departure definitions, settings, or security/audit records.
- Supabase Auth owns login, registration, and password-reset endpoints. The app adds a short client cooldown for accidental bursts, while Supabase Auth's provider limits remain authoritative. IP-based progressive blocking for Auth itself requires a deployed Supabase Edge Function or same-origin server proxy; it cannot be made authoritative from a browser-only static SPA or SQL trigger.
- The PWA service worker does not runtime-cache Supabase responses, sessions, or private student data.

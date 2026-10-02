# El Saidy Travel — Project Status

## Completed in this revision

- Replaced the rectangular reference-image treatment in the application shell with a clean transparent `public/branding/saidy-mark.svg` mark plus normal El Saidy Travel text.
- Removed Notifications from the student mobile menu. Notifications remain available from the header bell and the existing notifications route.
- Reworked the mobile menu as a rounded floating bottom panel with large touch targets, safe-area padding, backdrop fallback, short opening animation, and `prefers-reduced-motion` support.
- Neutralized the visual system: near-black/charcoal dark mode, neutral solid cards, soft white/gray borders, teal accent, white/soft-gray text, lighter shadows, no large gradients/video, and no heavy backdrop blur.
- Rebuilt admin bookings around clickable station groups. The screen defaults to today plus confirmed/active bookings and supports date, departure time, station, search, all/active/cancelled/boarded/no-show filters, counts, station details, student name/ID/phone, and `tel:` call buttons.
- Added `/admin/security` for admins/staff to inspect open and resolved suspicious-activity events, severity, actor, reason, metadata, and temporary blocks.
- Added `supabase/migrations/0006_security_events_and_rate_limits.sql` with `security_events`, `security_principals`, score-based progressive warnings/rate limits, temporary blocks, admin alerts, booking/request/profile/reference-data guards, subscription RPC protection, and least-privilege grants.
- Added a small client-side auth cooldown for login, signup, and password reset to reduce accidental bursts. Supabase Auth provider throttling remains authoritative.
- Replaced the legacy SuezBus favicon and generated PWA icons with the clean El Saidy mark; updated the platform logo metadata to the new opaque icon.

## Security boundaries

- Authorization is enforced by Supabase RLS, security-definer RPCs, database triggers, and grants. The UI role check is only a presentation convenience.
- Students cannot directly mutate subscriptions, roles, approval fields, approved Student IDs, booking ownership/trip metadata, trips, station definitions, departure definitions, admin settings, audit logs, or security events.
- Repeated protected booking/request/profile/reference-data attempts raise security events and can transition a principal through warning, rate-limited, and temporary-block states. Critical activity notifies approved admin/staff profiles.
- Login, registration, and password-reset requests terminate at Supabase Auth. IP-specific progressive blocking for those endpoints requires a deployed Supabase Edge Function or same-origin server proxy; a static browser SPA and SQL trigger cannot authoritatively enforce IP limits. The app does not claim that the local cooldown is a security boundary.

## Validation performed

- `npm run typecheck` — passed after the UI/API/security integration changes.
- `npm run build` — passed after the final UI, API, branding, and security edits; generated `dist/index.html`, `manifest.webmanifest`, `sw.js`, hashed assets, and PWA icons.
- `npm run lint` — passed (the project lint script runs the TypeScript build check).
- `git diff --check` and secret/generated-file checks are required before checkpointing.
- Independent read-only integration review completed. Supabase migration application, live RLS/ACL behavior, and production Auth throttling remain unverified until the migrations are applied to the connected project.

## Key files changed

- `src/app/App.tsx`
- `src/styles/index.css`
- `src/lib/api.ts`
- `src/hooks/useAuth.ts`
- `src/i18n/index.ts`
- `src/types/domain.ts`
- `tailwind.config.ts`
- `route-manifest.json`
- `public/branding/saidy-mark.svg`
- `public/favicon.svg` and `public/icons/icon-192.png` / `icon-512.png`
- `app.config.ts` and `vite.config.ts`
- `supabase/migrations/0006_security_events_and_rate_limits.sql`
- `supabase/README.md`
- `README.md`

## Operational note

The project remains a static Vite PWA using Supabase for authenticated dynamic data. No service-role key is present in the frontend. Do not commit `.env`, `.env.local`, or any real Supabase secret.

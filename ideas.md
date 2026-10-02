# Design direction — Suez–Galala Bus Reservation

## Theme Name
Route Control

## Intro
A calm, high-trust transport operations interface: deep navy for navigation and authority, sea-teal for active movement and success, warm amber for attention, and paper-like surfaces for legibility in the sun or at night.

## Design movement
Modern civic utility with a polished fleet-operations feel. The UI should feel dependable and fast rather than flashy.

## Core principles
- One clear action per card.
- Operational status is always visible through color plus text.
- Mobile-first controls with generous touch targets.
- Arabic is the primary reading experience; English is a complete equal path.
- Use whitespace and hierarchy instead of dense decoration.

## Color philosophy
- Ink navy: `#0b1f33` for the brand and shell.
- Route teal: `#0f9d8a` for confirmed movement and primary actions.
- Sky: `#e6f5f3` for calm information surfaces.
- Amber: `#f2a93b` for pending and expiring states.
- Rose: `#d9535f` for rejected, cancelled, and destructive states.
- Light canvas: `#f4f7f8`; dark canvas: `#07131f`.

## Layout paradigm
A responsive application shell with a compact top bar on mobile and a vertical rail on desktop. The dashboard opens with a welcome/status card followed by KPI cards, actionable alerts, and focused tables. Admin tables become stacked records on narrow viewports.

## Signature elements
A route-line motif with a simple bus silhouette, round status dots, bilingual status chips, and subtle diagonal route stripes used sparingly in empty states and the login welcome panel.

## Interaction philosophy
Fast, forgiving, and explicit. Buttons show pressed feedback; async work shows skeletons or progress; destructive operations use confirmation dialogs; errors tell the user what to do next in Arabic or English.

## Animation
Short ease-out transitions for cards, route changes, dialogs, and booking confirmation. No looping decorative animation and no motion that blocks the task.

## Typography system
Use a system-first stack that renders Arabic cleanly: `Cairo`, `Noto Sans Arabic`, `Inter`, system sans-serif. Use tabular numbers for KPIs and dates. Headings are compact and medium-weight; body text is readable at mobile sizes.

## Brand essence
A reliable daily route between a student and their campus.

## Brand voice
Clear, practical, respectful, reassuring.

## Wordmark/logo
A flat navy square with a teal route line forming a bus-window shape and a small amber destination dot. No baked-in text so it remains legible as an app icon.

## Signature brand color
Route teal `#0f9d8a`.

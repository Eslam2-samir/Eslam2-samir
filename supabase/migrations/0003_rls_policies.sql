alter table public.student_registry enable row level security;
alter table public.stations enable row level security;
alter table public.profiles enable row level security;
alter table public.subscriptions enable row level security;
alter table public.departure_times enable row level security;
alter table public.trips enable row level security;
alter table public.bookings enable row level security;
alter table public.notifications enable row level security;
alter table public.admin_settings enable row level security;
alter table public.audit_logs enable row level security;

create policy "active stations are readable" on public.stations for select to authenticated using (is_active or public.is_admin_or_staff());
create policy "admins manage stations" on public.stations for all to authenticated using (public.is_admin_or_staff()) with check (public.is_admin_or_staff());

create policy "active departure times are readable" on public.departure_times for select to authenticated using (is_active or public.is_admin_or_staff());
create policy "admins manage departure times" on public.departure_times for all to authenticated using (public.is_admin_or_staff()) with check (public.is_admin_or_staff());

create policy "students see own profile" on public.profiles for select to authenticated using (id = auth.uid() or public.is_admin_or_staff());
create policy "students edit safe profile fields" on public.profiles for update to authenticated using (id = auth.uid()) with check (id = auth.uid());
create policy "admins manage profiles" on public.profiles for all to authenticated using (public.is_admin_or_staff()) with check (public.is_admin_or_staff());

create policy "students see own subscription" on public.subscriptions for select to authenticated using (profile_id = auth.uid() or public.is_admin_or_staff());
create policy "admins manage subscriptions" on public.subscriptions for all to authenticated using (public.is_admin_or_staff()) with check (public.is_admin_or_staff());

create policy "authenticated users see future trip availability" on public.trips for select to authenticated using (service_date >= current_date or public.is_admin_or_staff());
create policy "admins manage trips" on public.trips for all to authenticated using (public.is_admin_or_staff()) with check (public.is_admin_or_staff());

create policy "students see own bookings" on public.bookings for select to authenticated using (profile_id = auth.uid() or public.is_admin_or_staff());
create policy "admins update bookings" on public.bookings for update to authenticated using (public.is_admin_or_staff()) with check (public.is_admin_or_staff());

create policy "students see own notifications" on public.notifications for select to authenticated using (profile_id = auth.uid());
create policy "students mark own notifications read" on public.notifications for update to authenticated using (profile_id = auth.uid()) with check (profile_id = auth.uid());
create policy "admins see notifications they own" on public.notifications for select to authenticated using (profile_id = auth.uid());

create policy "admins manage settings" on public.admin_settings for all to authenticated using (public.is_admin_or_staff()) with check (public.is_admin_or_staff());
create policy "admins read audit logs" on public.audit_logs for select to authenticated using (public.is_admin_or_staff());
create policy "admins read student registry" on public.student_registry for select to authenticated using (public.is_admin_or_staff());
create policy "admins manage student registry" on public.student_registry for all to authenticated using (public.is_admin_or_staff()) with check (public.is_admin_or_staff());

revoke all on public.student_registry from anon, authenticated;
revoke update on public.profiles from authenticated;
revoke all on public.admin_settings from anon, authenticated;
revoke all on public.audit_logs from anon, authenticated;

grant select, insert, update, delete on public.student_registry to authenticated;
grant update (full_name, student_id, phone, university, default_station_id) on public.profiles to authenticated;
grant select, insert, update, delete on public.admin_settings to authenticated;
grant select on public.audit_logs to authenticated;

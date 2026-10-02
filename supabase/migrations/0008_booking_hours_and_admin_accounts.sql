-- Dynamic booking hours and database-enforced administrator blocking.
-- Existing rows are preserved; all new settings default to 08:00-22:00.

alter table public.profiles
  add column if not exists admin_status text not null default 'active';

alter table public.profiles
  drop constraint if exists profiles_admin_status_check;
alter table public.profiles
  add constraint profiles_admin_status_check check (admin_status in ('active', 'blocked'));

insert into public.admin_settings (key, value, description)
values
  ('booking_open_time', '08:00', 'Daily local time when new bookings open.'),
  ('booking_close_time', '22:00', 'Daily local time when new bookings close.')
on conflict (key) do nothing;

create or replace function public.is_admin_or_staff() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid()
      and role in ('admin', 'staff')
      and account_status = 'approved'
      and admin_status = 'active'
  );
$$;

create or replace function public.is_active_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid()
      and role = 'admin'
      and account_status = 'approved'
      and admin_status = 'active'
  );
$$;

create or replace function public.booking_hours_open() returns boolean
language plpgsql stable security definer set search_path = public as $$
declare
  v_open time;
  v_close time;
  v_now time := (current_timestamp at time zone 'Africa/Cairo')::time;
begin
  select nullif(value, '')::time into v_open from public.admin_settings where key = 'booking_open_time';
  select nullif(value, '')::time into v_close from public.admin_settings where key = 'booking_close_time';
  v_open := coalesce(v_open, time '08:00');
  v_close := coalesce(v_close, time '22:00');
  if v_open = v_close then return false; end if;
  if v_open < v_close then return v_now >= v_open and v_now < v_close; end if;
  return v_now >= v_open or v_now < v_close;
end;
$$;

create or replace function public.create_booking_batch(p_station_id uuid, p_departure_time_id uuid, p_dates date[])
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_user uuid := auth.uid();
  v_sub public.subscriptions;
  v_station public.stations;
  v_time public.departure_times;
  v_date date;
  v_trip public.trips;
  v_capacity integer;
  v_batch uuid := gen_random_uuid();
  v_result jsonb := '[]'::jsonb;
  v_booking public.bookings;
begin
  if v_user is null then raise exception using errcode = 'P0001', message = 'AUTH_REQUIRED'; end if;
  perform public.security_assert_allowed('booking_create');
  if not exists (select 1 from public.profiles where id = v_user and account_status <> 'suspended' and role = 'student') then raise exception using errcode = 'P0001', message = 'ACCOUNT_NOT_ALLOWED'; end if;
  if not public.booking_hours_open() then raise exception using errcode = 'P0001', message = 'BOOKING_HOURS_CLOSED'; end if;
  select * into v_sub from public.subscriptions where profile_id = v_user and status = 'active' order by end_date desc limit 1;
  if not found or v_sub.end_date < current_date then raise exception using errcode = 'P0001', message = 'SUBSCRIPTION_EXPIRED'; end if;
  select * into v_station from public.stations where id = p_station_id and is_active;
  if not found then raise exception using errcode = 'P0001', message = 'STATION_UNAVAILABLE'; end if;
  select * into v_time from public.departure_times where id = p_departure_time_id and is_active;
  if not found then raise exception using errcode = 'P0001', message = 'DEPARTURE_UNAVAILABLE'; end if;
  if coalesce(array_length(p_dates, 1), 0) = 0 then raise exception using errcode = 'P0001', message = 'DATES_REQUIRED'; end if;
  select value::integer into v_capacity from public.admin_settings where key = 'default_trip_capacity';
  v_capacity := coalesce(v_capacity, 40);

  foreach v_date in array p_dates loop
    if v_date < current_date then raise exception using errcode = 'P0001', message = 'DATE_IN_PAST'; end if;
    if v_date > current_date + coalesce((select value::integer from public.admin_settings where key = 'booking_horizon_days'), 30) then raise exception using errcode = 'P0001', message = 'DATE_OUT_OF_RANGE'; end if;
    if exists (select 1 from public.bookings where profile_id = v_user and service_date = v_date and status <> 'cancelled') then raise exception using errcode = '23505', message = 'BOOKING_DUPLICATE_DATE'; end if;
    insert into public.trips (service_date, departure_time_id, capacity) values (v_date, p_departure_time_id, v_capacity) on conflict (service_date, departure_time_id) do nothing;
    select * into v_trip from public.trips where service_date = v_date and departure_time_id = p_departure_time_id for update;
    if v_trip.status = 'closed' or v_trip.booked_count >= v_trip.capacity then raise exception using errcode = 'P0001', message = 'BOOKING_CAPACITY_FULL'; end if;
    insert into public.bookings (profile_id, station_id, trip_id, service_date, departure_time, booking_batch_id)
      values (v_user, p_station_id, v_trip.id, v_date, v_time.time, v_batch) returning * into v_booking;
    update public.trips set booked_count = booked_count + 1, status = case when booked_count + 1 >= capacity then 'full' else 'open' end where id = v_trip.id;
    v_result := v_result || jsonb_build_array(jsonb_build_object('id', v_booking.id, 'service_date', v_booking.service_date, 'departure_time', v_booking.departure_time, 'station_id', v_booking.station_id, 'status', v_booking.status));
  end loop;
  insert into public.notifications (profile_id, kind, title, body, metadata) values (v_user, 'booking_confirmed', 'Booking confirmed', 'Your selected bus trips are confirmed.', jsonb_build_object('booking_batch_id', v_batch));
  return jsonb_build_object('batchId', v_batch, 'bookings', v_result);
exception when unique_violation then
  raise exception using errcode = '23505', message = 'BOOKING_DUPLICATE_DATE';
end;
$$;

create or replace function public.create_booking_change_request(p_date date, p_station_id uuid, p_departure_time_id uuid, p_reason text default null)
returns public.booking_change_requests
language plpgsql security definer set search_path = public as $$
declare v_user uuid := auth.uid(); v_request public.booking_change_requests;
begin
  perform public.security_assert_allowed('booking_request_create');
  if not exists (select 1 from public.profiles where id = v_user and role = 'student' and account_status <> 'suspended') then raise exception using errcode = 'P0001', message = 'ACCOUNT_NOT_ALLOWED'; end if;
  if not public.booking_hours_open() then raise exception using errcode = 'P0001', message = 'BOOKING_HOURS_CLOSED'; end if;
  if extract(dow from p_date)::smallint = any(coalesce((select preferred_weekdays from public.profiles where id = v_user), array[0,1,2,3,4,5,6]::smallint[])) then raise exception using errcode = 'P0001', message = 'DATE_ALREADY_IN_SCHEDULE'; end if;
  insert into public.booking_change_requests (profile_id, requested_date, station_id, departure_time_id, reason) values (v_user, p_date, p_station_id, p_departure_time_id, p_reason) returning * into v_request;
  insert into public.notifications (profile_id, kind, title, body, metadata) values (v_user, 'booking_request_submitted', 'Booking request submitted', 'Your off-schedule booking request is waiting for company review.', jsonb_build_object('request_id', v_request.id, 'requested_date', p_date));
  return v_request;
end;
$$;

create or replace function public.protect_profile_changes() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  perform public.security_assert_allowed('profile_update');
  if not public.is_admin_or_staff() then
    if old.role is distinct from new.role or old.account_status is distinct from new.account_status or old.admin_status is distinct from new.admin_status or old.approved_at is distinct from new.approved_at or old.approved_by is distinct from new.approved_by or (old.account_status = 'approved' and old.student_id is distinct from new.student_id) then
      perform public.security_record_event('protected_profile_change', 'A student attempted to change a protected profile field.', jsonb_build_object('profile_id', old.id), 'high');
    end if;
    new.role := old.role;
    new.account_status := old.account_status;
    new.admin_status := old.admin_status;
    new.approved_at := old.approved_at;
    new.approved_by := old.approved_by;
    if old.account_status = 'approved' then new.student_id := old.student_id; end if;
  end if;
  return new;
end;
$$;

grant execute on function public.booking_hours_open() to authenticated;

create or replace function public.get_booking_hours() returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'openTime', coalesce((select value from public.admin_settings where key = 'booking_open_time'), '08:00'),
    'closeTime', coalesce((select value from public.admin_settings where key = 'booking_close_time'), '22:00')
  );
$$;

create or replace function public.admin_update_booking_hours(p_open_time text, p_close_time text) returns void
language plpgsql security definer set search_path = public as $$
declare v_open time; v_close time; v_before jsonb; v_after jsonb;
begin
  perform public.admin_security_guard('booking_hours_update');
  if not public.is_active_admin() then raise exception using errcode = '42501', message = 'ADMIN_REQUIRED'; end if;
  if p_open_time !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$' or p_close_time !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$' then raise exception using errcode = '22007', message = 'INVALID_BOOKING_HOURS'; end if;
  begin v_open := p_open_time::time; v_close := p_close_time::time; exception when others then raise exception using errcode = '22007', message = 'INVALID_BOOKING_HOURS'; end;
  if v_open = v_close then raise exception using errcode = '22023', message = 'BOOKING_HOURS_EQUAL'; end if;
  select jsonb_object_agg(key, value) into v_before from public.admin_settings where key in ('booking_open_time', 'booking_close_time');
  insert into public.admin_settings (key, value, description, updated_by) values
    ('booking_open_time', to_char(v_open, 'HH24:MI'), 'Daily local time when new bookings open.', auth.uid()),
    ('booking_close_time', to_char(v_close, 'HH24:MI'), 'Daily local time when new bookings close.', auth.uid())
  on conflict (key) do update set value = excluded.value, updated_by = auth.uid(), updated_at = now();
  select jsonb_object_agg(key, value) into v_after from public.admin_settings where key in ('booking_open_time', 'booking_close_time');
  insert into public.audit_logs (actor_id, action, entity_type, before_data, after_data) values (auth.uid(), 'booking_hours_updated', 'admin_settings', v_before, v_after);
end;
$$;

create or replace function public.admin_update_admin_status(p_profile_id uuid, p_status text) returns void
language plpgsql security definer set search_path = public as $$
declare v_target public.profiles; v_before jsonb; v_after jsonb; v_active_count integer;
begin
  perform public.admin_security_guard('admin_status_update');
  if not public.is_active_admin() then raise exception using errcode = '42501', message = 'ADMIN_REQUIRED'; end if;
  if p_status not in ('active', 'blocked') then raise exception using errcode = '22023', message = 'INVALID_ADMIN_STATUS'; end if;
  select * into v_target from public.profiles where id = p_profile_id and role in ('admin', 'staff') for update;
  if not found then raise exception using errcode = 'P0001', message = 'ADMIN_NOT_FOUND'; end if;
  if v_target.id = auth.uid() then raise exception using errcode = '42501', message = 'ADMIN_SELF_BLOCK'; end if;
  if p_status = 'blocked' and v_target.admin_status = 'active' then
    select count(*) into v_active_count from public.profiles where role in ('admin', 'staff') and account_status = 'approved' and admin_status = 'active';
    if v_active_count <= 1 then raise exception using errcode = '42501', message = 'LAST_ACTIVE_ADMIN'; end if;
  end if;
  v_before := to_jsonb(v_target);
  update public.profiles set admin_status = p_status where id = p_profile_id;
  select to_jsonb(p) into v_after from public.profiles p where id = p_profile_id;
  insert into public.audit_logs (actor_id, action, entity_type, entity_id, before_data, after_data) values (auth.uid(), case when p_status = 'blocked' then 'admin_blocked' else 'admin_unblocked' end, 'profiles', p_profile_id, v_before, v_after);
end;
$$;

alter table public.admin_settings enable row level security;

-- Recreate the settings policy with the active-admin-aware helper.
drop policy if exists "admins manage settings" on public.admin_settings;
create policy "admins manage settings" on public.admin_settings for all to authenticated using (public.is_admin_or_staff()) with check (public.is_admin_or_staff());

grant execute on function public.admin_update_booking_hours(text, text) to authenticated;
grant execute on function public.admin_update_admin_status(uuid, text) to authenticated;
grant execute on function public.get_booking_hours() to authenticated;

-- Keep direct profile writes from becoming an admin-status bypass.
revoke update on public.profiles from authenticated;
grant update (full_name, student_id, phone, university, default_station_id) on public.profiles to authenticated;

-- Make admin lists and audit reads available only through active admins/staff.
drop policy if exists "students see own profile" on public.profiles;
create policy "students see own profile" on public.profiles for select to authenticated using (id = auth.uid() or public.is_admin_or_staff());
drop policy if exists "admins read audit logs" on public.audit_logs;
create policy "admins read audit logs" on public.audit_logs for select to authenticated using (public.is_admin_or_staff());

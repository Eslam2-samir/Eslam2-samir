create or replace function public.is_admin_or_staff() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role in ('admin', 'staff') and account_status = 'approved'
  );
$$;

create or replace function public.protect_profile_changes() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin_or_staff() then
    new.role := old.role;
    new.account_status := old.account_status;
    new.approved_at := old.approved_at;
    new.approved_by := old.approved_by;
    if old.account_status = 'approved' then new.student_id := old.student_id; end if;
  end if;
  return new;
end;
$$;

create trigger protect_profile_changes before update on public.profiles for each row execute function public.protect_profile_changes();

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
  if not exists (select 1 from public.profiles where id = v_user and account_status = 'approved' and role = 'student') then raise exception using errcode = 'P0001', message = 'ACCOUNT_NOT_APPROVED'; end if;
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
    insert into public.trips (service_date, departure_time_id, capacity)
      values (v_date, p_departure_time_id, v_capacity)
      on conflict (service_date, departure_time_id) do nothing;
    select * into v_trip from public.trips where service_date = v_date and departure_time_id = p_departure_time_id for update;
    if v_trip.status = 'closed' or v_trip.booked_count >= v_trip.capacity then raise exception using errcode = 'P0001', message = 'BOOKING_CAPACITY_FULL'; end if;
    insert into public.bookings (profile_id, station_id, trip_id, service_date, departure_time, booking_batch_id)
      values (v_user, p_station_id, v_trip.id, v_date, v_time.time, v_batch)
      returning * into v_booking;
    update public.trips set booked_count = booked_count + 1, status = case when booked_count + 1 >= capacity then 'full' else 'open' end where id = v_trip.id;
    v_result := v_result || jsonb_build_array(jsonb_build_object('id', v_booking.id, 'service_date', v_booking.service_date, 'departure_time', v_booking.departure_time, 'station_id', v_booking.station_id, 'status', v_booking.status));
  end loop;
  insert into public.notifications (profile_id, kind, title, body, metadata) values (v_user, 'booking_confirmed', 'Booking confirmed', 'Your selected bus trips are confirmed.', jsonb_build_object('booking_batch_id', v_batch));
  return jsonb_build_object('batchId', v_batch, 'bookings', v_result);
exception when unique_violation then
  raise exception using errcode = '23505', message = 'BOOKING_DUPLICATE_DATE';
end;
$$;

create or replace function public.cancel_booking(p_booking_id uuid) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_booking public.bookings;
  v_cutoff integer;
begin
  select * into v_booking from public.bookings where id = p_booking_id and (profile_id = auth.uid() or public.is_admin_or_staff()) for update;
  if not found then raise exception using errcode = 'P0001', message = 'BOOKING_NOT_FOUND'; end if;
  if v_booking.status = 'cancelled' then return; end if;
  select value::integer into v_cutoff from public.admin_settings where key = 'cancellation_cutoff_hours';
  if not public.is_admin_or_staff() and (v_booking.service_date::timestamp + v_booking.departure_time - now()) < make_interval(hours => coalesce(v_cutoff, 4)) then raise exception using errcode = 'P0001', message = 'CANCELLATION_CUTOFF'; end if;
  update public.bookings set status = 'cancelled', cancelled_at = now(), cancelled_by = auth.uid() where id = p_booking_id;
  if v_booking.trip_id is not null then update public.trips set booked_count = greatest(0, booked_count - 1), status = case when booked_count - 1 < capacity then 'open' else status end where id = v_booking.trip_id; end if;
  insert into public.notifications (profile_id, kind, title, body, metadata) values (v_booking.profile_id, 'booking_cancelled', 'Booking cancelled', 'Your booking was cancelled.', jsonb_build_object('booking_id', p_booking_id));
end;
$$;

create or replace function public.admin_update_profile_status(p_profile_id uuid, p_status public.account_status) returns void
language plpgsql security definer set search_path = public as $$
declare v_before jsonb; v_after jsonb;
begin
  if not public.is_admin_or_staff() then raise exception using errcode = '42501', message = 'ADMIN_REQUIRED'; end if;
  select to_jsonb(p) into v_before from public.profiles p where id = p_profile_id;
  update public.profiles set account_status = p_status, approved_at = case when p_status = 'approved' then now() else approved_at end, approved_by = case when p_status = 'approved' then auth.uid() else approved_by end where id = p_profile_id;
  select to_jsonb(p) into v_after from public.profiles p where id = p_profile_id;
  insert into public.audit_logs (actor_id, action, entity_type, entity_id, before_data, after_data) values (auth.uid(), 'profile_status_changed', 'profiles', p_profile_id, v_before, v_after);
  insert into public.notifications (profile_id, kind, title, body) values (p_profile_id, 'account_status', 'Account status updated', 'Your account status has been updated by the company.');
end;
$$;

create or replace function public.admin_update_booking_status(p_booking_id uuid, p_status public.booking_status) returns void
language plpgsql security definer set search_path = public as $$
declare v_before jsonb; v_after jsonb; v_booking public.bookings; v_trip public.trips;
begin
  if not public.is_admin_or_staff() then raise exception using errcode = '42501', message = 'ADMIN_REQUIRED'; end if;
  select * into v_booking from public.bookings where id = p_booking_id for update;
  if not found then raise exception using errcode = 'P0001', message = 'BOOKING_NOT_FOUND'; end if;
  v_before := to_jsonb(v_booking);
  if v_booking.status <> 'cancelled' and p_status = 'cancelled' and v_booking.trip_id is not null then
    update public.trips set booked_count = greatest(0, booked_count - 1), status = case when booked_count - 1 < capacity then 'open' else status end where id = v_booking.trip_id;
    update public.bookings set status = p_status, cancelled_at = now(), cancelled_by = auth.uid() where id = p_booking_id;
    insert into public.notifications (profile_id, kind, title, body, metadata) values (v_booking.profile_id, 'booking_cancelled', 'Booking cancelled', 'Your booking was cancelled by the company.', jsonb_build_object('booking_id', p_booking_id));
  elsif v_booking.status = 'cancelled' and p_status <> 'cancelled' and v_booking.trip_id is not null then
    select * into v_trip from public.trips where id = v_booking.trip_id for update;
    if v_trip.booked_count >= v_trip.capacity then raise exception using errcode = 'P0001', message = 'BOOKING_CAPACITY_FULL'; end if;
    update public.trips set booked_count = booked_count + 1, status = case when booked_count + 1 >= capacity then 'full' else 'open' end where id = v_booking.trip_id;
    update public.bookings set status = p_status, cancelled_at = null, cancelled_by = null where id = p_booking_id;
  else
    update public.bookings set status = p_status where id = p_booking_id;
  end if;
  select to_jsonb(b) into v_after from public.bookings b where id = p_booking_id;
  insert into public.audit_logs (actor_id, action, entity_type, entity_id, before_data, after_data) values (auth.uid(), 'booking_status_changed', 'bookings', p_booking_id, v_before, v_after);
end;
$$;

create or replace function public.admin_dashboard_stats() returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_today date := current_date; v_tomorrow date := current_date + 1; v_capacity integer;
begin
  if not public.is_admin_or_staff() then raise exception using errcode = '42501', message = 'ADMIN_REQUIRED'; end if;
  select coalesce(sum(capacity), 0) into v_capacity from public.trips where service_date = v_today;
  return jsonb_build_object(
    'totalStudents', (select count(*) from public.profiles where role = 'student'),
    'pendingStudents', (select count(*) from public.profiles where role = 'student' and account_status = 'pending'),
    'activeSubscriptions', (select count(*) from public.subscriptions where status = 'active' and end_date >= current_date),
    'expiringSubscriptions', (select count(*) from public.subscriptions where status = 'active' and end_date between current_date and current_date + 3),
    'expiredSubscriptions', (select count(*) from public.subscriptions where status = 'expired' or end_date < current_date),
    'todayBookings', (select count(*) from public.bookings where service_date = v_today and status <> 'cancelled'),
    'tomorrowBookings', (select count(*) from public.bookings where service_date = v_tomorrow and status <> 'cancelled'),
    'todayPassengers', (select count(*) from public.bookings where service_date = v_today and status in ('confirmed', 'boarded')),
    'tripCapacity', v_capacity
  );
end;
$$;

create or replace function public.create_subscription_alerts() returns integer
language plpgsql security definer set search_path = public as $$
declare v_count integer := 0; item record; v_days integer;
begin
  for item in select s.*, p.full_name from public.subscriptions s join public.profiles p on p.id = s.profile_id where s.status = 'active' and s.end_date <= current_date + 3 loop
    v_days := item.end_date - current_date;
    if not exists (select 1 from public.notifications n where n.profile_id = item.profile_id and n.kind = 'subscription_expiring' and (n.metadata->>'end_date') = item.end_date::text) then
      insert into public.notifications (profile_id, kind, title, body, metadata) values (item.profile_id, 'subscription_expiring', 'Subscription expiring', case when v_days <= 0 then 'Your subscription has expired.' else 'Your subscription expires in ' || v_days || ' day(s).' end, jsonb_build_object('end_date', item.end_date));
      v_count := v_count + 1;
    end if;
    if item.end_date < current_date then update public.subscriptions set status = 'expired' where id = item.id; end if;
  end loop;
  return v_count;
end;
$$;

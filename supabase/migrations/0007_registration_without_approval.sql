-- New student registrations are usable immediately. The account_status column
-- remains available for admin suspension and legacy status management.
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, full_name, student_id, email, phone, university, default_station_id, account_status, approved_at)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', 'New student'),
    coalesce(new.raw_user_meta_data->>'student_id', 'pending-' || substr(new.id::text, 1, 8)),
    new.email,
    coalesce(new.raw_user_meta_data->>'phone', 'pending-' || substr(new.id::text, 1, 8)),
    new.raw_user_meta_data->>'university',
    nullif(new.raw_user_meta_data->>'default_station_id', '')::uuid,
    'approved',
    now()
  );
  return new;
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
  if not exists (select 1 from public.profiles where id = v_user and account_status <> 'suspended' and role = 'student') then raise exception using errcode = 'P0001', message = 'ACCOUNT_NOT_ALLOWED'; end if;
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

-- Keep the off-schedule booking-request path consistent with normal bookings.
create or replace function public.create_booking_change_request(p_date date, p_station_id uuid, p_departure_time_id uuid, p_reason text default null)
returns public.booking_change_requests
language plpgsql security definer set search_path = public as $$
declare v_user uuid := auth.uid(); v_request public.booking_change_requests;
begin
  if not exists (select 1 from public.profiles where id = v_user and role = 'student' and account_status <> 'suspended') then raise exception using errcode = 'P0001', message = 'ACCOUNT_NOT_ALLOWED'; end if;
  if extract(dow from p_date)::smallint = any(coalesce((select preferred_weekdays from public.profiles where id = v_user), array[0,1,2,3,4,5,6]::smallint[])) then raise exception using errcode = 'P0001', message = 'DATE_ALREADY_IN_SCHEDULE'; end if;
  insert into public.booking_change_requests (profile_id, requested_date, station_id, departure_time_id, reason)
    values (v_user, p_date, p_station_id, p_departure_time_id, p_reason)
    returning * into v_request;
  insert into public.notifications (profile_id, kind, title, body, metadata) values (v_user, 'booking_request_submitted', 'Booking request submitted', 'Your off-schedule booking request is waiting for company review.', jsonb_build_object('request_id', v_request.id, 'requested_date', p_date));
  return v_request;
end;
$$;

-- Security events, progressive protection, and database-enforced write guards.
-- Auth endpoints themselves remain owned by Supabase Auth; see supabase/README.md.

create table if not exists public.security_principals (
  profile_id uuid primary key references public.profiles(id) on delete cascade,
  score integer not null default 0 check (score >= 0),
  state text not null default 'normal' check (state in ('normal', 'warning', 'rate_limited', 'temporarily_blocked', 'admin_review')),
  window_started_at timestamptz not null default now(),
  blocked_until timestamptz,
  last_event_at timestamptz,
  updated_at timestamptz not null default now()
);

create table if not exists public.security_events (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references public.profiles(id) on delete set null,
  event_type text not null,
  severity text not null default 'warning' check (severity in ('info', 'warning', 'high', 'critical')),
  action text,
  reason text not null,
  metadata jsonb not null default '{}'::jsonb,
  blocked_until timestamptz,
  resolved_at timestamptz,
  reviewed_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);

create index if not exists security_events_actor_created_idx on public.security_events (actor_id, created_at desc);
create index if not exists security_events_open_idx on public.security_events (resolved_at, severity, created_at desc);

create or replace function public.security_record_event(
  p_event_type text,
  p_reason text,
  p_metadata jsonb default '{}'::jsonb,
  p_severity text default 'warning'
) returns public.security_events
language plpgsql security definer set search_path = public as $$
declare
  v_actor uuid := auth.uid();
  v_principal public.security_principals;
  v_event public.security_events;
  v_weight integer := case p_severity when 'critical' then 8 when 'high' then 5 when 'warning' then 2 else 1 end;
  v_score integer;
  v_state text := 'normal';
  v_blocked_until timestamptz := null;
begin
  if v_actor is null then raise exception using errcode = 'P0001', message = 'AUTH_REQUIRED'; end if;
  insert into public.security_principals (profile_id) values (v_actor) on conflict (profile_id) do nothing;
  select * into v_principal from public.security_principals where profile_id = v_actor for update;
  if v_principal.window_started_at < now() - interval '15 minutes' then
    v_principal.score := 0;
    v_principal.window_started_at := now();
  end if;
  v_score := v_principal.score + v_weight;
  if v_score >= 20 then
    v_state := 'temporarily_blocked';
    v_blocked_until := now() + interval '1 hour';
  elsif v_score >= 10 then
    v_state := 'rate_limited';
    v_blocked_until := now() + interval '10 minutes';
  elsif v_score >= 5 then
    v_state := 'warning';
  end if;
  update public.security_principals
  set score = v_score, state = v_state, window_started_at = v_principal.window_started_at,
      blocked_until = v_blocked_until, last_event_at = now(), updated_at = now()
  where profile_id = v_actor;
  insert into public.security_events (actor_id, event_type, severity, action, reason, metadata, blocked_until)
  values (v_actor, p_event_type, p_severity, p_event_type, p_reason, coalesce(p_metadata, '{}'::jsonb), v_blocked_until)
  returning * into v_event;
  if v_score >= 20 then
    insert into public.notifications (profile_id, kind, title, body, metadata)
    select id, 'security_alert', 'Security Alert', 'A serious suspicious activity event requires review.', jsonb_build_object('event_id', v_event.id, 'actor_id', v_actor, 'event_type', p_event_type)
    from public.profiles where role in ('admin', 'staff') and account_status = 'approved';
  end if;
  return v_event;
end;
$$;

create or replace function public.security_assert_allowed(p_action text) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_actor uuid := auth.uid();
  v_principal public.security_principals;
begin
  if v_actor is null then raise exception using errcode = 'P0001', message = 'AUTH_REQUIRED'; end if;
  select * into v_principal from public.security_principals where profile_id = v_actor;
  if found and v_principal.blocked_until is not null and v_principal.blocked_until > now() then
    insert into public.security_events (actor_id, event_type, severity, action, reason, metadata, blocked_until)
    values (v_actor, 'blocked_request', 'critical', p_action, 'Temporary security block is active.', jsonb_build_object('state', v_principal.state), v_principal.blocked_until);
    raise exception using errcode = 'P0001', message = 'SECURITY_TEMPORARY_BLOCK';
  end if;
  if found and v_principal.blocked_until is not null and v_principal.blocked_until <= now() then
    update public.security_principals set state = 'normal', score = 0, blocked_until = null, window_started_at = now(), updated_at = now() where profile_id = v_actor;
  end if;
end;
$$;

create or replace function public.admin_security_guard(p_action text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin_or_staff() then
    perform public.security_record_event('unauthorized_admin_operation', 'A non-admin attempted a privileged operation.', jsonb_build_object('action', p_action), 'high');
    raise exception using errcode = '42501', message = 'ADMIN_REQUIRED';
  end if;
  perform public.security_assert_allowed(p_action);
end;
$$;

create or replace function public.guard_booking_write() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  perform public.security_assert_allowed(case when tg_op = 'INSERT' then 'booking_create' else 'booking_update' end);
  if tg_op = 'UPDATE' and not public.is_admin_or_staff() then
    if old.profile_id <> auth.uid() or new.profile_id <> old.profile_id or new.station_id <> old.station_id or new.trip_id is distinct from old.trip_id or new.service_date <> old.service_date or new.departure_time <> old.departure_time or new.booking_batch_id <> old.booking_batch_id then
      perform public.security_record_event('protected_booking_change', 'A student attempted to change booking ownership or trip fields.', jsonb_build_object('booking_id', old.id), 'high');
      raise exception using errcode = '42501', message = 'BOOKING_FIELDS_PROTECTED';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists bookings_security_guard on public.bookings;
create trigger bookings_security_guard before insert or update on public.bookings for each row execute function public.guard_booking_write();

create or replace function public.guard_booking_request_write() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  perform public.security_assert_allowed('booking_request_create');
  if new.profile_id <> auth.uid() and not public.is_admin_or_staff() then
    perform public.security_record_event('unauthorized_booking_request', 'A student attempted to create a request for another student.', jsonb_build_object('request_id', new.id), 'high');
    raise exception using errcode = '42501', message = 'REQUEST_OWNER_PROTECTED';
  end if;
  return new;
end;
$$;

drop trigger if exists booking_change_requests_security_guard on public.booking_change_requests;
create trigger booking_change_requests_security_guard before insert or update on public.booking_change_requests for each row execute function public.guard_booking_request_write();

create or replace function public.guard_admin_reference_write() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  perform public.admin_security_guard(tg_table_name || '_' || lower(tg_op));
  return case when tg_op = 'DELETE' then old else new end;
end;
$$;

drop trigger if exists stations_security_guard on public.stations;
create trigger stations_security_guard before insert or update or delete on public.stations for each row execute function public.guard_admin_reference_write();
drop trigger if exists departure_times_security_guard on public.departure_times;
create trigger departure_times_security_guard before insert or update or delete on public.departure_times for each row execute function public.guard_admin_reference_write();
drop trigger if exists admin_settings_security_guard on public.admin_settings;
create trigger admin_settings_security_guard before insert or update or delete on public.admin_settings for each row execute function public.guard_admin_reference_write();

create or replace function public.protect_profile_changes() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  perform public.security_assert_allowed('profile_update');
  if not public.is_admin_or_staff() then
    if old.role is distinct from new.role or old.account_status is distinct from new.account_status or old.approved_at is distinct from new.approved_at or old.approved_by is distinct from new.approved_by or (old.account_status = 'approved' and old.student_id is distinct from new.student_id) then
      perform public.security_record_event('protected_profile_change', 'A student attempted to change a protected profile field.', jsonb_build_object('profile_id', old.id), 'high');
    end if;
    new.role := old.role;
    new.account_status := old.account_status;
    new.approved_at := old.approved_at;
    new.approved_by := old.approved_by;
    if old.account_status = 'approved' then new.student_id := old.student_id; end if;
  end if;
  return new;
end;
$$;

create or replace function public.admin_update_subscription(
  p_subscription_id uuid,
  p_start_date date,
  p_end_date date,
  p_status public.subscription_status
) returns void
language plpgsql security definer set search_path = public as $$
declare v_before jsonb; v_after jsonb;
begin
  perform public.admin_security_guard('subscription_update');
  select to_jsonb(s) into v_before from public.subscriptions s where id = p_subscription_id for update;
  if v_before is null then raise exception using errcode = 'P0001', message = 'SUBSCRIPTION_NOT_FOUND'; end if;
  update public.subscriptions set start_date = p_start_date, end_date = p_end_date, status = p_status, updated_by = auth.uid() where id = p_subscription_id;
  select to_jsonb(s) into v_after from public.subscriptions s where id = p_subscription_id;
  insert into public.audit_logs (actor_id, action, entity_type, entity_id, before_data, after_data) values (auth.uid(), 'subscription_updated', 'subscriptions', p_subscription_id, v_before, v_after);
end;
$$;

alter table public.security_principals enable row level security;
alter table public.security_events enable row level security;
create policy "admins read security principals" on public.security_principals for select to authenticated using (public.is_admin_or_staff());
create policy "admins read security events" on public.security_events for select to authenticated using (public.is_admin_or_staff());
create policy "admins resolve security events" on public.security_events for update to authenticated using (public.is_admin_or_staff()) with check (public.is_admin_or_staff());

revoke all on public.security_principals from anon, authenticated;
revoke all on public.security_events from anon, authenticated;
grant select on public.security_principals to authenticated;
grant select, update on public.security_events to authenticated;
grant execute on function public.security_record_event(text, text, jsonb, text) to authenticated;
grant execute on function public.security_assert_allowed(text) to authenticated;
grant execute on function public.admin_security_guard(text) to authenticated;
grant execute on function public.admin_update_subscription(uuid, date, date, public.subscription_status) to authenticated;
revoke execute on function public.create_subscription_alerts() from public, anon, authenticated;
grant execute on function public.create_subscription_alerts() to service_role;

revoke insert, update, delete on public.subscriptions from authenticated;
grant select on public.subscriptions to authenticated;
revoke insert, update, delete on public.bookings from authenticated;
grant select on public.bookings to authenticated;
revoke insert, update, delete on public.trips from authenticated;
grant select on public.trips to authenticated;
revoke insert, update, delete on public.stations from authenticated;
grant select on public.stations to authenticated;
revoke insert, update, delete on public.departure_times from authenticated;
grant select on public.departure_times to authenticated;
revoke all on public.admin_settings from authenticated;
revoke insert, update, delete on public.audit_logs from authenticated;
grant select on public.audit_logs to authenticated;

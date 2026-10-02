create extension if not exists pgcrypto;

create type public.app_role as enum ('student', 'admin', 'staff');
create type public.account_status as enum ('pending', 'approved', 'rejected', 'suspended');
create type public.subscription_status as enum ('active', 'expired', 'paused', 'pending');
create type public.booking_status as enum ('confirmed', 'cancelled', 'boarded', 'no_show');
create type public.trip_status as enum ('open', 'full', 'closed');

create table public.student_registry (
  id uuid primary key default gen_random_uuid(),
  student_id text not null,
  university text,
  full_name text,
  is_active boolean not null default true,
  is_used boolean not null default false,
  created_at timestamptz not null default now(),
  unique (student_id)
);

create table public.stations (
  id uuid primary key default gen_random_uuid(),
  name_ar text not null,
  name_en text,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  student_id text not null,
  email text not null,
  phone text not null,
  university text,
  default_station_id uuid references public.stations(id) on delete set null,
  role public.app_role not null default 'student',
  account_status public.account_status not null default 'pending',
  approved_at timestamptz,
  approved_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index profiles_student_id_unique on public.profiles (lower(student_id));
create unique index profiles_phone_unique on public.profiles (regexp_replace(phone, '\\D', '', 'g'));

create table public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  start_date date not null,
  end_date date not null,
  status public.subscription_status not null default 'pending',
  created_by uuid references public.profiles(id) on delete set null,
  updated_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (end_date >= start_date)
);

create table public.departure_times (
  id uuid primary key default gen_random_uuid(),
  time time not null,
  label text,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (time)
);

create table public.trips (
  id uuid primary key default gen_random_uuid(),
  service_date date not null,
  departure_time_id uuid not null references public.departure_times(id) on delete restrict,
  capacity integer not null default 40 check (capacity > 0),
  booked_count integer not null default 0 check (booked_count >= 0),
  status public.trip_status not null default 'open',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (service_date, departure_time_id)
);

create table public.bookings (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  station_id uuid not null references public.stations(id) on delete restrict,
  trip_id uuid references public.trips(id) on delete restrict,
  service_date date not null,
  departure_time time not null,
  status public.booking_status not null default 'confirmed',
  booking_batch_id uuid not null,
  cancelled_at timestamptz,
  cancelled_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index bookings_one_active_per_day on public.bookings (profile_id, service_date) where status <> 'cancelled';
create index bookings_date_time_idx on public.bookings (service_date, departure_time);
create index bookings_profile_idx on public.bookings (profile_id, service_date desc);

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  kind text not null,
  title text not null,
  body text not null,
  is_read boolean not null default false,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table public.admin_settings (
  key text primary key,
  value text not null,
  description text,
  updated_by uuid references public.profiles(id) on delete set null,
  updated_at timestamptz not null default now()
);

create table public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references public.profiles(id) on delete set null,
  action text not null,
  entity_type text not null,
  entity_id uuid,
  before_data jsonb,
  after_data jsonb,
  created_at timestamptz not null default now()
);

create or replace function public.set_updated_at() returns trigger
language plpgsql security invoker set search_path = public as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger stations_updated_at before update on public.stations for each row execute function public.set_updated_at();
create trigger profiles_updated_at before update on public.profiles for each row execute function public.set_updated_at();
create trigger subscriptions_updated_at before update on public.subscriptions for each row execute function public.set_updated_at();
create trigger departure_times_updated_at before update on public.departure_times for each row execute function public.set_updated_at();
create trigger trips_updated_at before update on public.trips for each row execute function public.set_updated_at();
create trigger bookings_updated_at before update on public.bookings for each row execute function public.set_updated_at();

create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, full_name, student_id, email, phone, university, default_station_id)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', 'New student'),
    coalesce(new.raw_user_meta_data->>'student_id', 'pending-' || substr(new.id::text, 1, 8)),
    new.email,
    coalesce(new.raw_user_meta_data->>'phone', 'pending-' || substr(new.id::text, 1, 8)),
    new.raw_user_meta_data->>'university',
    nullif(new.raw_user_meta_data->>'default_station_id', '')::uuid
  );
  return new;
end;
$$;

create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_user();

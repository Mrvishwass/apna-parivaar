-- Apna Parivaar – Database Schema and Policies

-- Extensions
create extension if not exists "uuid-ossp";

-- Tables
create table if not exists public.profiles (
  id uuid primary key default auth.uid(),
  email text,
  name text,
  role text check (role in ('Super Admin','Family Admin','Sub Admin','Member')),
  family_name text,
  created_at timestamp with time zone default now()
);

create table if not exists public.families (
  id uuid primary key default uuid_generate_v4(),
  family_name text unique,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamp with time zone default now()
);

create table if not exists public.members (
  id uuid primary key default uuid_generate_v4(),
  family_id uuid references public.families(id) on delete cascade,
  name text,
  gender text,
  occupation text,
  location text,
  relation text,
  created_at timestamp with time zone default now()
);

create table if not exists public.payments (
  id uuid primary key default uuid_generate_v4(),
  family_admin_id uuid references public.profiles(id) on delete set null,
  email text,
  qr_url text,
  status text default 'pending',
  created_at timestamp with time zone default now()
);

-- Enable RLS
alter table public.profiles enable row level security;
alter table public.families enable row level security;
alter table public.members enable row level security;
alter table public.payments enable row level security;

-- Helper: get current user's role and family name
create or replace view public.current_user_profile as
select id, role, family_name, email, name
from public.profiles
where id = auth.uid();

-- Policies: profiles
drop policy if exists profiles_self_select on public.profiles;
create policy profiles_self_select on public.profiles
for select
to authenticated
using (
  id = auth.uid() or
  exists (
    select 1 from public.profiles p2
    where p2.id = auth.uid() and p2.role = 'Super Admin'
  )
);

drop policy if exists profiles_self_update on public.profiles;
create policy profiles_self_update on public.profiles
for update
to authenticated
using (id = auth.uid())
with check (id = auth.uid());

drop policy if exists profiles_insert_self on public.profiles;
create policy profiles_insert_self on public.profiles
for insert
to authenticated
with check (id = auth.uid());

-- Policies: families
drop policy if exists families_read_by_family_or_super on public.families;
create policy families_read_by_family_or_super on public.families
for select
to authenticated
using (
  exists (
    select 1 from public.profiles up
    where up.id = auth.uid()
      and (up.role = 'Super Admin' or up.family_name = families.family_name)
  )
);

drop policy if exists families_admin_insert on public.families;
create policy families_admin_insert on public.families
for insert
to authenticated
with check (
  exists (
    select 1 from public.profiles up
    where up.id = auth.uid() and up.role in ('Super Admin','Family Admin')
  )
);

drop policy if exists families_admin_update on public.families;
create policy families_admin_update on public.families
for update
to authenticated
using (
  exists (
    select 1 from public.profiles up
    where up.id = auth.uid() and up.role in ('Super Admin','Family Admin')
  )
)
with check (
  exists (
    select 1 from public.profiles up
    where up.id = auth.uid() and up.role in ('Super Admin','Family Admin')
  )
);

-- Policies: members
drop policy if exists members_read_same_family_or_super on public.members;
create policy members_read_same_family_or_super on public.members
for select
to authenticated
using (
  exists (
    select 1 from public.profiles up
    join public.families f on f.family_name = up.family_name
    where up.id = auth.uid() and (up.role = 'Super Admin' or f.id = members.family_id)
  )
);

drop policy if exists members_write_family_admins on public.members;
create policy members_write_family_admins on public.members
for all
to authenticated
using (
  exists (
    select 1 from public.profiles up
    join public.families f on f.family_name = up.family_name
    where up.id = auth.uid()
      and up.role in ('Family Admin','Sub Admin')
      and f.id = members.family_id
  )
)
with check (
  exists (
    select 1 from public.profiles up
    join public.families f on f.family_name = up.family_name
    where up.id = auth.uid()
      and up.role in ('Family Admin','Sub Admin')
      and f.id = members.family_id
  )
);

-- Policies: payments
drop policy if exists payments_read_own_or_super on public.payments;
create policy payments_read_own_or_super on public.payments
for select
to authenticated
using (
  exists (
    select 1 from public.profiles up
    where up.id = auth.uid() and (up.role = 'Super Admin' or up.id = payments.family_admin_id)
  )
);

drop policy if exists payments_insert_admin on public.payments;
create policy payments_insert_admin on public.payments
for insert
to authenticated
with check (
  exists (
    select 1 from public.profiles up
    where up.id = auth.uid() and up.role in ('Family Admin','Super Admin')
  )
);

drop policy if exists payments_update_admin on public.payments;
create policy payments_update_admin on public.payments
for update
to authenticated
using (
  exists (
    select 1 from public.profiles up
    where up.id = auth.uid() and (up.role in ('Family Admin','Super Admin'))
  )
)
with check (
  exists (
    select 1 from public.profiles up
    where up.id = auth.uid() and (up.role in ('Family Admin','Super Admin'))
  )
);

-- Triggers: ensure a family row exists for a new profile.family_name
create or replace function public.ensure_family_for_profile()
returns trigger language plpgsql as $$
begin
  if new.family_name is not null and not exists (
    select 1 from public.families f where f.family_name = new.family_name
  ) then
    insert into public.families (family_name, created_by) values (new.family_name, new.id);
  end if;
  return new;
end; $$;

drop trigger if exists trg_profiles_ensure_family on public.profiles;
create trigger trg_profiles_ensure_family
after insert on public.profiles
for each row execute function public.ensure_family_for_profile();



create type public.app_role as enum (
  'director',
  'secretary',
  'teacher',
  'finance',
  'guardian'
);

create table public.institutions (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  cnpj text unique not null,
  city text,
  state char(2),
  status text not null default 'active'
    check (status in ('active', 'suspended', 'canceled')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
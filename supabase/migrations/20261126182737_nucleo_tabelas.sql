-- =====================================================================
-- Núcleo multi-tenant — tipos e tabelas
-- Tabelas: institutions, profiles, institution_users, audit_logs
-- RLS é ativado aqui mesmo (tabela nasce fechada); as policies vêm na
-- migration nucleo_rls.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Papéis de um usuário dentro de uma escola
-- ---------------------------------------------------------------------
create type public.app_role as enum (
  'director',
  'secretary',
  'teacher',
  'finance',
  'guardian'
);

comment on type public.app_role is
  'Papel do usuário em uma escola. Exibido em PT-BR no frontend.';

-- ---------------------------------------------------------------------
-- institutions — escolas clientes (tenants)
-- ---------------------------------------------------------------------
create table public.institutions (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  cnpj        text not null unique check (cnpj ~ '^[0-9]{14}$'),
  city        text,
  state       char(2) check (state ~ '^[A-Z]{2}$'),
  status      text not null default 'active'
                check (status in ('active', 'suspended', 'canceled')),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

comment on table public.institutions is
  'Escolas clientes (tenants) da plataforma.';
comment on column public.institutions.cnpj is
  'Somente dígitos (14). A máscara é aplicada no frontend.';
comment on column public.institutions.status is
  'active = em uso; suspended = acesso bloqueado (ex.: inadimplência), dados mantidos; canceled = saiu da plataforma (fluxo de exclusão LGPD).';

alter table public.institutions enable row level security;

-- ---------------------------------------------------------------------
-- profiles — dados do usuário (1 para 1 com auth.users)
-- ---------------------------------------------------------------------
create table public.profiles (
  id                 uuid primary key references auth.users (id) on delete cascade,
  full_name          text,
  phone              text check (phone ~ '^55[0-9]{10,11}$'),
  is_platform_admin  boolean not null default false,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);

comment on table public.profiles is
  'Perfil de cada usuário autenticado. O id é o mesmo de auth.users.';
comment on column public.profiles.phone is
  'Somente dígitos com DDI 55 + DDD + número (formato exigido pelo WhatsApp).';
comment on column public.profiles.is_platform_admin is
  'Administrador da plataforma GSchool (não de uma escola). Nunca alterável pelo próprio usuário.';

alter table public.profiles enable row level security;

-- ---------------------------------------------------------------------
-- institution_users — vínculo pessoa × escola × papel
-- ---------------------------------------------------------------------
create table public.institution_users (
  id              uuid primary key default gen_random_uuid(),
  institution_id  uuid not null references public.institutions (id) on delete cascade,
  profile_id      uuid not null references public.profiles (id) on delete cascade,
  role            public.app_role not null,
  active          boolean not null default true,
  created_at      timestamptz not null default now(),
  unique (institution_id, profile_id, role)
);

-- A constraint unique acima já cria um índice que começa por
-- institution_id, então só falta o índice por profile_id
-- (usado em toda verificação "de quais escolas este usuário é membro?").
create index institution_users_profile_id_idx
  on public.institution_users (profile_id);

comment on table public.institution_users is
  'Vínculo de um usuário com uma escola e seu papel nela. Base do isolamento multi-tenant.';

alter table public.institution_users enable row level security;

-- ---------------------------------------------------------------------
-- audit_logs — registro imutável de alterações
-- ---------------------------------------------------------------------
-- Sem foreign keys de propósito: o log precisa sobreviver à exclusão
-- da escola ou do usuário que ele descreve.
create table public.audit_logs (
  id              bigint generated always as identity primary key,
  institution_id  uuid,
  actor_id        uuid,
  action          text not null check (action in ('INSERT', 'UPDATE', 'DELETE')),
  entity          text not null,
  entity_id       uuid,
  before          jsonb,
  after           jsonb,
  created_at      timestamptz not null default now()
);

create index audit_logs_institution_created_idx
  on public.audit_logs (institution_id, created_at desc);

comment on table public.audit_logs is
  'Auditoria: quem alterou o quê e quando. Gravado só por trigger; somente leitura para a diretora.';

alter table public.audit_logs enable row level security;
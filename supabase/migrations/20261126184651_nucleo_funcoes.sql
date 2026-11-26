-- =====================================================================
-- Núcleo multi-tenant — funções auxiliares e triggers
-- Tudo no schema "private", que NÃO é exposto pela API REST.
-- Regra: toda função security definer tem set search_path = ''
-- e referencia objetos com o schema explícito.
-- =====================================================================

create schema if not exists private;

comment on schema private is
  'Funções internas (helpers de RLS e triggers). Não exposto pela API.';

-- As policies rodam com o papel de quem faz a requisição (authenticated),
-- então esse papel precisa "enxergar" o schema para chamar as funções.
-- supabase_auth_admin é quem dispara o trigger em auth.users.
grant usage on schema private to authenticated, supabase_auth_admin;

-- ---------------------------------------------------------------------
-- 4.2 updated_at automático
-- ---------------------------------------------------------------------
create function private.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger set_updated_at
  before update on public.institutions
  for each row execute function private.set_updated_at();

create trigger set_updated_at
  before update on public.profiles
  for each row execute function private.set_updated_at();

-- ---------------------------------------------------------------------
-- 4.3 Novo usuário em auth.users → cria o profile
-- ---------------------------------------------------------------------
create function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, full_name)
  values (new.id, new.raw_user_meta_data ->> 'full_name');
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function private.handle_new_user();

-- ---------------------------------------------------------------------
-- 4.4 O usuário logado tem vínculo ativo com a escola?
-- ---------------------------------------------------------------------
create function private.is_member(inst uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.institution_users iu
    where iu.institution_id = inst
      and iu.profile_id = (select auth.uid())
      and iu.active
  );
$$;

comment on function private.is_member(uuid) is
  'Verdadeiro se o usuário logado tem vínculo ativo com a escola. Usado nas policies.';

-- ---------------------------------------------------------------------
-- 4.5 O usuário logado tem um destes papéis na escola?
-- ---------------------------------------------------------------------
create function private.has_role(inst uuid, roles public.app_role[])
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.institution_users iu
    where iu.institution_id = inst
      and iu.profile_id = (select auth.uid())
      and iu.active
      and iu.role = any (roles)
  );
$$;

comment on function private.has_role(uuid, public.app_role[]) is
  'Verdadeiro se o usuário logado tem um dos papéis informados (vínculo ativo) na escola.';

-- ---------------------------------------------------------------------
-- Extra: o usuário logado compartilha alguma escola com outro perfil?
-- (usado na policy de SELECT de profiles: ver colegas da mesma escola)
-- ---------------------------------------------------------------------
create function private.shares_institution_with(target uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.institution_users me
    join public.institution_users other
      on other.institution_id = me.institution_id
    where me.profile_id = (select auth.uid())
      and me.active
      and other.profile_id = target
      and other.active
  );
$$;

comment on function private.shares_institution_with(uuid) is
  'Verdadeiro se o usuário logado e o perfil informado têm vínculo ativo com uma mesma escola.';

-- ---------------------------------------------------------------------
-- Extra: impedir que um usuário se promova a admin da plataforma
-- ---------------------------------------------------------------------
-- Trigger SEM security definer: current_user é o papel de quem fez a
-- requisição. Pela API (anon/authenticated) a mudança é bloqueada;
-- pelo painel/SQL Editor (postgres) ou service_role é permitida.
create function private.protect_platform_admin()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.is_platform_admin is distinct from old.is_platform_admin
     and current_user in ('anon', 'authenticated') then
    raise exception 'is_platform_admin cannot be changed by the user'
      using errcode = '42501'; -- insufficient_privilege
  end if;
  return new;
end;
$$;

create trigger protect_platform_admin
  before update on public.profiles
  for each row execute function private.protect_platform_admin();

-- ---------------------------------------------------------------------
-- 4.6 Auditoria genérica (antes/depois de cada alteração)
-- ---------------------------------------------------------------------
-- Pressupõe que a tabela auditada tem "id" uuid e, se não for a própria
-- institutions, uma coluna "institution_id".
create function private.audit_row_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_before     jsonb;
  v_after      jsonb;
  v_entity_id  uuid;
  v_inst       uuid;
begin
  if tg_op in ('UPDATE', 'DELETE') then
    v_before := to_jsonb(old);
  end if;
  if tg_op in ('INSERT', 'UPDATE') then
    v_after := to_jsonb(new);
  end if;

  v_entity_id := coalesce(v_after ->> 'id', v_before ->> 'id')::uuid;

  if tg_table_name = 'institutions' then
    v_inst := v_entity_id;
  else
    v_inst := coalesce(v_after ->> 'institution_id', v_before ->> 'institution_id')::uuid;
  end if;

  insert into public.audit_logs
    (institution_id, actor_id, action, entity, entity_id, before, after)
  values
    (v_inst, (select auth.uid()), tg_op, tg_table_name, v_entity_id, v_before, v_after);

  return null; -- trigger AFTER: o retorno é ignorado
end;
$$;

create trigger audit_row_change
  after insert or update or delete on public.institutions
  for each row execute function private.audit_row_change();

create trigger audit_row_change
  after insert or update or delete on public.institution_users
  for each row execute function private.audit_row_change();
-- =====================================================================
-- Núcleo multi-tenant — políticas de acesso (RLS)
-- O RLS já foi ativado na migration nucleo_tabelas (tabelas fechadas).
-- Aqui abrimos só o necessário, sempre para usuários logados.
-- =====================================================================

-- ---------------------------------------------------------------------
-- institutions
-- ---------------------------------------------------------------------
-- Ver: só as escolas onde tenho vínculo ativo.
create policy "institutions_select_member"
  on public.institutions for select
  to authenticated
  using (private.is_member(id));

-- Alterar: só a diretora da escola.
create policy "institutions_update_director"
  on public.institutions for update
  to authenticated
  using (private.has_role(id, '{director}'))
  with check (private.has_role(id, '{director}'));

-- Criar/apagar escola: nenhuma policy de propósito.
-- Será feito por uma função do admin da plataforma (tópico futuro).

-- ---------------------------------------------------------------------
-- profiles
-- ---------------------------------------------------------------------
-- Ver: o meu perfil e o de colegas que têm escola em comum comigo.
create policy "profiles_select_self_or_colleague"
  on public.profiles for select
  to authenticated
  using (
    id = (select auth.uid())
    or private.shares_institution_with(id)
  );

-- Alterar: só o meu próprio perfil.
-- (is_platform_admin é protegido pelo trigger protect_platform_admin)
create policy "profiles_update_self"
  on public.profiles for update
  to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

-- Criar: feito pelo trigger handle_new_user. Apagar: em cascata a partir de auth.users.

-- ---------------------------------------------------------------------
-- institution_users
-- ---------------------------------------------------------------------
-- Ver: vínculos das escolas onde sou membro.
create policy "institution_users_select_member"
  on public.institution_users for select
  to authenticated
  using (private.is_member(institution_id));

-- Criar / alterar / apagar vínculos: só a diretora da escola.
create policy "institution_users_insert_director"
  on public.institution_users for insert
  to authenticated
  with check (private.has_role(institution_id, '{director}'));

create policy "institution_users_update_director"
  on public.institution_users for update
  to authenticated
  using (private.has_role(institution_id, '{director}'))
  with check (private.has_role(institution_id, '{director}'));

create policy "institution_users_delete_director"
  on public.institution_users for delete
  to authenticated
  using (private.has_role(institution_id, '{director}'));

-- ---------------------------------------------------------------------
-- audit_logs
-- ---------------------------------------------------------------------
-- Ver: só a diretora, e só os registros da escola dela.
create policy "audit_logs_select_director"
  on public.audit_logs for select
  to authenticated
  using (private.has_role(institution_id, '{director}'));

-- Ninguém grava, altera ou apaga pela API: só o trigger de auditoria.
-- Além de não haver policy, retiramos a permissão (defesa em camadas).
revoke insert, update, delete, truncate on public.audit_logs from anon, authenticated;
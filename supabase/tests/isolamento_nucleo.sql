-- =====================================================================
-- Testes de isolamento entre escolas — núcleo
-- Rodar no SQL Editor do gschool-dev DEPOIS do seed.sql.
-- Tudo roda dentro de begin/rollback: nada fica gravado.
-- Resultado esperado: a última linha mostra "TODOS OS TESTES PASSARAM".
-- Se algum falhar, aparece um erro começando com "FALHOU".
-- =====================================================================

begin;

-- Guarda os ids dos usuários de teste (como admin, antes de simular login)
select
  set_config('test.dir_a',  (select id::text from auth.users where email = 'diretora.a@teste.dev'),   true),
  set_config('test.prof_a', (select id::text from auth.users where email = 'professora.a@teste.dev'), true),
  set_config('test.prof_b', (select id::text from auth.users where email = 'professora.b@teste.dev'), true),
  set_config('test.esc_a', 'aaaaaaaa-0000-4000-8000-000000000001', true),
  set_config('test.esc_b', 'bbbbbbbb-0000-4000-8000-000000000002', true);

do $$
begin
  if current_setting('test.dir_a', true) is null
     or current_setting('test.prof_a', true) is null
     or current_setting('test.prof_b', true) is null then
    raise exception 'FALHOU: usuários de teste não encontrados. Crie os usuários e rode o seed.sql antes.';
  end if;
end $$;

-- =====================================================================
-- Como DIRETORA A
-- =====================================================================
set local role authenticated;
select set_config('request.jwt.claims',
  json_build_object('sub', current_setting('test.dir_a'), 'role', 'authenticated')::text, true);

do $$
declare n int;
begin
  -- 8.1 vê 1 escola (a A) e nada da B
  select count(*) into n from public.institutions;
  if n <> 1 then raise exception 'FALHOU 8.1: diretora A vê % escolas (esperado 1)', n; end if;

  select count(*) into n from public.institutions where id = current_setting('test.esc_b')::uuid;
  if n <> 0 then raise exception 'FALHOU 8.1: diretora A enxerga a escola B'; end if;

  -- 8.4 não consegue criar vínculo na escola B
  begin
    insert into public.institution_users (institution_id, profile_id, role)
    values (current_setting('test.esc_b')::uuid, current_setting('test.prof_a')::uuid, 'teacher');
    raise exception 'FALHOU 8.4: diretora A criou vínculo na escola B';
  exception when insufficient_privilege then null;
  end;

  -- 8.4 também não consegue "mover" um vínculo da A para a B
  begin
    update public.institution_users
       set institution_id = current_setting('test.esc_b')::uuid
     where institution_id = current_setting('test.esc_a')::uuid;
    raise exception 'FALHOU 8.4: diretora A moveu vínculo para a escola B';
  exception when insufficient_privilege then null;
  end;

  -- não vê o perfil da professora B (não são colegas)
  select count(*) into n from public.profiles where id = current_setting('test.prof_b')::uuid;
  if n <> 0 then raise exception 'FALHOU: diretora A enxerga o perfil da professora B'; end if;

  -- 8.8 (parte 1) diretora A cria um vínculo na própria escola → deve funcionar
  insert into public.institution_users (institution_id, profile_id, role)
  values (current_setting('test.esc_a')::uuid, current_setting('test.prof_a')::uuid, 'secretary');

  -- 8.7 ninguém altera/apaga audit_logs
  begin
    delete from public.audit_logs;
    raise exception 'FALHOU 8.7: diretora A apagou audit_logs';
  exception when insufficient_privilege then null;
  end;

  begin
    update public.audit_logs set action = 'DELETE';
    raise exception 'FALHOU 8.7: diretora A alterou audit_logs';
  exception when insufficient_privilege then null;
  end;

  raise notice 'OK: testes da diretora A';
end $$;

reset role;

-- =====================================================================
-- Como PROFESSORA A
-- =====================================================================
set local role authenticated;
select set_config('request.jwt.claims',
  json_build_object('sub', current_setting('test.prof_a'), 'role', 'authenticated')::text, true);

do $$
declare n int;
begin
  -- 8.2 vê vínculos da escola A e nenhum da B
  select count(*) into n from public.institution_users
   where institution_id = current_setting('test.esc_a')::uuid;
  if n = 0 then raise exception 'FALHOU 8.2: professora A não vê os vínculos da escola A'; end if;

  select count(*) into n from public.institution_users
   where institution_id = current_setting('test.esc_b')::uuid;
  if n <> 0 then raise exception 'FALHOU 8.2: professora A vê vínculos da escola B'; end if;

  -- 8.3 não cria vínculo (só diretora)
  begin
    insert into public.institution_users (institution_id, profile_id, role)
    values (current_setting('test.esc_a')::uuid, current_setting('test.prof_a')::uuid, 'director');
    raise exception 'FALHOU 8.3: professora A criou vínculo (virou diretora)';
  exception when insufficient_privilege then null;
  end;

  -- 8.3 não altera a escola (update silenciosamente afeta 0 linhas)
  update public.institutions set name = 'Hackeada'
   where id = current_setting('test.esc_a')::uuid;
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'FALHOU 8.3: professora A alterou a escola'; end if;

  -- não vê auditoria (só diretora)
  select count(*) into n from public.audit_logs;
  if n <> 0 then raise exception 'FALHOU: professora A vê audit_logs'; end if;

  -- 8.5 não consegue virar admin da plataforma
  begin
    update public.profiles set is_platform_admin = true
     where id = current_setting('test.prof_a')::uuid;
    raise exception 'FALHOU 8.5: professora A virou admin da plataforma';
  exception when insufficient_privilege then null;
  end;

  -- mas consegue editar o próprio nome
  update public.profiles set full_name = 'Professora A (editado)'
   where id = current_setting('test.prof_a')::uuid;
  get diagnostics n = row_count;
  if n <> 1 then raise exception 'FALHOU: professora A não conseguiu editar o próprio perfil'; end if;

  raise notice 'OK: testes da professora A';
end $$;

reset role;

-- =====================================================================
-- Como ANÔNIMO (não logado) — 8.6
-- =====================================================================
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);

do $$
declare n int;
begin
  select count(*) into n from public.institutions;      if n <> 0 then raise exception 'FALHOU 8.6: anon vê institutions'; end if;
  select count(*) into n from public.profiles;          if n <> 0 then raise exception 'FALHOU 8.6: anon vê profiles'; end if;
  select count(*) into n from public.institution_users; if n <> 0 then raise exception 'FALHOU 8.6: anon vê institution_users'; end if;
  select count(*) into n from public.audit_logs;        if n <> 0 then raise exception 'FALHOU 8.6: anon vê audit_logs'; end if;
  raise notice 'OK: testes do anônimo';
end $$;

reset role;

-- =====================================================================
-- 8.8 (parte 2) o vínculo criado pela diretora A gerou auditoria
-- =====================================================================
do $$
declare n int;
begin
  select count(*) into n from public.audit_logs
   where entity = 'institution_users'
     and action = 'INSERT'
     and actor_id = current_setting('test.dir_a')::uuid
     and after ->> 'role' = 'secretary';
  if n <> 1 then raise exception 'FALHOU 8.8: auditoria do novo vínculo não encontrada'; end if;
end $$;

rollback;

select 'TODOS OS TESTES PASSARAM' as resultado;

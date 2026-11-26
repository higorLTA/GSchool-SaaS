-- =====================================================================
-- Dados fictícios para o ambiente de DESENVOLVIMENTO (gschool-dev).
-- NUNCA executar em produção.
--
-- Pré-requisito: criar no painel (Authentication → Add user) os usuários:
--   diretora.a@teste.dev, professora.a@teste.dev  (Escola A)
--   diretora.b@teste.dev, professora.b@teste.dev  (Escola B)
--
-- Pode ser executado mais de uma vez sem duplicar nada.
-- =====================================================================

-- Garante um profile para cada usuário (cobre usuários criados antes
-- do trigger handle_new_user existir)
insert into public.profiles (id, full_name)
select u.id, u.raw_user_meta_data ->> 'full_name'
from auth.users u
on conflict (id) do nothing;

-- Escolas (CNPJs fictícios, gerados com dígitos verificadores válidos)
insert into public.institutions (id, name, cnpj, city, state)
values
  ('aaaaaaaa-0000-4000-8000-000000000001', 'Escola Fictícia A', '11222333000181', 'São Paulo', 'SP'),
  ('bbbbbbbb-0000-4000-8000-000000000002', 'Escola Fictícia B', '44555666000181', 'Campinas',  'SP')
on conflict (id) do nothing;

-- Vínculos (busca o id de cada usuário pelo e-mail)
insert into public.institution_users (institution_id, profile_id, role)
select v.institution_id::uuid, u.id, v.role::public.app_role
from (
  values
    ('aaaaaaaa-0000-4000-8000-000000000001', 'diretora.a@teste.dev',   'director'),
    ('aaaaaaaa-0000-4000-8000-000000000001', 'professora.a@teste.dev', 'teacher'),
    ('bbbbbbbb-0000-4000-8000-000000000002', 'diretora.b@teste.dev',   'director'),
    ('bbbbbbbb-0000-4000-8000-000000000002', 'professora.b@teste.dev', 'teacher')
) as v (institution_id, email, role)
join auth.users u on u.email = v.email
on conflict (institution_id, profile_id, role) do nothing;

-- Conferência: deve listar 4 vínculos
select i.name as escola, u.email, iu.role
from public.institution_users iu
join public.institutions i on i.id = iu.institution_id
join auth.users u on u.id = iu.profile_id
order by i.name, iu.role;
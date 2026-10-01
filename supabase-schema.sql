-- =====================================================================
-- RANCHO PEP OLIVAS — banco de dados (Supabase / Postgres)
-- Cole este arquivo inteiro em: Supabase > SQL Editor > New query > Run
-- Pode ser executado mais de uma vez sem duplicar dados.
-- =====================================================================

-- ---------- TABELAS ----------
create table if not exists public.config (
  id                 int primary key default 1 check (id = 1),
  nome_loja          text not null default 'Rancho Pep Olivas',
  whatsapp           text not null default '5511999999999',
  mensagem_whatsapp  text not null default 'Olá! Vim pelo site do *Rancho Pep Olivas* e gostaria de fazer um pedido.',
  pix_chave          text not null default '',
  pix_cidade         text not null default 'SAO PAULO',
  logo_url           text,
  instagram          text,
  facebook           text,
  outro_link_rotulo  text,
  outro_link_url     text,
  chatbot_ativo      boolean not null default false,
  tema               jsonb   not null default '{}'::jsonb,   -- cores personalizadas
  textos             jsonb   not null default '{}'::jsonb,   -- textos do site (título, história, FAQ, política...)
  banner_ativo       boolean not null default false,
  banner_texto       text,
  banner_link        text,
  verificar_idade    boolean not null default true,          -- portão "tenho 18 anos ou mais"
  frete_fixo_centavos          int check (frete_fixo_centavos is null or frete_fixo_centavos >= 0),  -- null = "a combinar"
  frete_gratis_acima_centavos  int check (frete_gratis_acima_centavos is null or frete_gratis_acima_centavos >= 0),
  estoque_baixo      int not null default 5,
  atualizado_em      timestamptz not null default now()
);
insert into public.config (id) values (1) on conflict (id) do nothing;

create table if not exists public.produtos (
  id              uuid primary key default gen_random_uuid(),
  categoria       text not null check (categoria in ('vinhos','azeites','kits')),
  nome            text not null check (length(btrim(nome)) > 0),
  volume_ml       int check (volume_ml is null or volume_ml > 0),
  preco_centavos  int not null check (preco_centavos >= 0),
  estoque         int not null default 0 check (estoque >= 0),
  destaque        boolean not null default false,
  ativo           boolean not null default true,
  imagem_url      text,
  notas_prova     text,
  descricao       text,
  criado_em       timestamptz not null default now()
);

create table if not exists public.cupons (
  id               uuid primary key default gen_random_uuid(),
  codigo           text not null unique check (codigo = upper(btrim(codigo)) and length(codigo) between 3 and 30),
  tipo             text not null check (tipo in ('percentual','valor')),
  valor            int  not null check (valor > 0),          -- % (1 a 100) ou centavos
  minimo_centavos  int  not null default 0 check (minimo_centavos >= 0),
  usos_max         int  check (usos_max is null or usos_max > 0),
  usos             int  not null default 0,
  validade         date,
  ativo            boolean not null default true,
  criado_em        timestamptz not null default now(),
  check (tipo <> 'percentual' or valor <= 100)
);

create table if not exists public.admins (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  nome       text not null,
  email      text not null,
  criado_em  timestamptz not null default now()
);
alter table public.admins add column if not exists usuario text;
create unique index if not exists admins_usuario_unico on public.admins (lower(usuario)) where usuario is not null;

-- convites: e-mails que viram administrador assim que criarem a conta e verificarem o e-mail
create table if not exists public.admin_convites (
  email      text primary key check (email = lower(btrim(email))),
  nome       text not null,
  criado_em  timestamptz not null default now()
);

create table if not exists public.pedidos (
  id                  uuid primary key default gen_random_uuid(),
  numero              bigint generated always as identity unique,
  cliente_nome        text not null,
  cliente_telefone    text not null,
  tipo_entrega        text not null check (tipo_entrega in ('entrega','retirada')),
  cep                 text,
  logradouro          text,
  numero_end          text,
  complemento         text,
  bairro              text,
  cidade              text,
  uf                  text,
  observacoes         text,
  itens               jsonb not null,
  subtotal_centavos   bigint not null,
  desconto_centavos   bigint not null default 0,
  frete_centavos      bigint not null default 0,
  frete_a_combinar    boolean not null default false,
  cupom_codigo        text,
  total_centavos      bigint not null,
  forma_pagamento     text not null check (forma_pagamento in ('pix','cartao_entrega','dinheiro')),
  pagamento_status    text not null default 'pendente' check (pagamento_status in ('pendente','pago')),
  status              text not null default 'recebido'
                      check (status in ('recebido','confirmado','separacao','embalagem','enviado','entregue','cancelado')),
  criado_em           timestamptz not null default now(),
  atualizado_em       timestamptz not null default now()
);
create index if not exists pedidos_status_idx on public.pedidos (status, criado_em desc);

create table if not exists public.pedido_eventos (
  id         bigint generated always as identity primary key,
  pedido_id  uuid not null references public.pedidos(id) on delete cascade,
  status     text not null,
  por        text,
  criado_em  timestamptz not null default now()
);
create index if not exists pedido_eventos_pedido_idx on public.pedido_eventos (pedido_id, criado_em);

-- ---------- QUEM É ADMINISTRADOR ----------
create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  -- só é administrador quem está na tabela E já verificou o e-mail
  select exists (
    select 1 from public.admins a join auth.users u on u.id = a.user_id
     where a.user_id = auth.uid() and u.email_confirmed_at is not null);
$$;

-- ---------- SEGURANÇA (Row Level Security) ----------
alter table public.config         enable row level security;
alter table public.produtos       enable row level security;
alter table public.admins         enable row level security;
alter table public.pedidos        enable row level security;
alter table public.pedido_eventos enable row level security;
alter table public.cupons         enable row level security;
alter table public.admin_convites enable row level security;

drop policy if exists config_leitura   on public.config;
drop policy if exists config_edita     on public.config;
drop policy if exists produtos_leitura on public.produtos;
drop policy if exists produtos_insere  on public.produtos;
drop policy if exists produtos_edita   on public.produtos;
drop policy if exists produtos_apaga   on public.produtos;
drop policy if exists admins_leitura   on public.admins;
drop policy if exists pedidos_leitura  on public.pedidos;
drop policy if exists eventos_leitura  on public.pedido_eventos;
drop policy if exists cupons_admin     on public.cupons;

create policy config_leitura   on public.config   for select using (true);
create policy config_edita     on public.config   for update to authenticated using (public.is_admin()) with check (public.is_admin());
create policy produtos_leitura on public.produtos for select using (ativo or public.is_admin());
create policy produtos_insere  on public.produtos for insert to authenticated with check (public.is_admin());
create policy produtos_edita   on public.produtos for update to authenticated using (public.is_admin()) with check (public.is_admin());
create policy produtos_apaga   on public.produtos for delete to authenticated using (public.is_admin());
create policy admins_leitura   on public.admins   for select to authenticated using (public.is_admin());
create policy pedidos_leitura  on public.pedidos  for select to authenticated using (public.is_admin());
create policy eventos_leitura  on public.pedido_eventos for select to authenticated using (public.is_admin());
create policy cupons_admin     on public.cupons for all to authenticated using (public.is_admin()) with check (public.is_admin());

revoke all on public.config, public.produtos, public.admins, public.pedidos, public.pedido_eventos, public.cupons, public.admin_convites from anon, authenticated;
grant select, insert, update, delete on public.cupons to authenticated;
grant select on public.config, public.produtos to anon, authenticated;
grant update on public.config to authenticated;
grant insert, update, delete on public.produtos to authenticated;
grant select on public.admins, public.pedidos, public.pedido_eventos to authenticated;

-- ---------- CLIENTE: confere um cupom antes de finalizar ----------
create or replace function public.validar_cupom(p_codigo text, p_subtotal bigint)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_c public.cupons%rowtype;
  v_desc bigint;
begin
  select * into v_c from public.cupons
   where codigo = upper(btrim(coalesce(p_codigo, ''))) and ativo
     and (validade is null or validade >= current_date)
     and (usos_max is null or usos < usos_max);
  if not found then return jsonb_build_object('valido', false, 'mensagem', 'Cupom inválido ou expirado.'); end if;
  if p_subtotal < v_c.minimo_centavos then
    return jsonb_build_object('valido', false,
      'mensagem', 'Este cupom vale para pedidos a partir de R$ ' || to_char(v_c.minimo_centavos / 100.0, 'FM999990.00'));
  end if;
  v_desc := case when v_c.tipo = 'percentual' then round(p_subtotal * v_c.valor / 100.0) else least(v_c.valor, p_subtotal) end;
  return jsonb_build_object('valido', true, 'desconto_centavos', v_desc, 'mensagem', 'Cupom aplicado!');
end $$;

-- ---------- CLIENTE FAZ O PEDIDO (preço, cupom, frete e estoque conferidos AQUI, no servidor) ----------
create or replace function public.criar_pedido(p jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_nome   text := btrim(coalesce(p->>'cliente_nome', ''));
  v_tel    text := regexp_replace(coalesce(p->>'cliente_telefone', ''), '\D', '', 'g');
  v_tipo   text := coalesce(p->>'tipo_entrega', 'entrega');
  v_forma  text := coalesce(p->>'forma_pagamento', 'pix');
  v_cep    text := regexp_replace(coalesce(p->>'cep', ''), '\D', '', 'g');
  v_uf     text := upper(btrim(coalesce(p->>'uf', '')));
  v_cod    text := upper(btrim(coalesce(p->>'cupom', '')));
  v_item   jsonb;
  v_prod   public.produtos%rowtype;
  v_cfg    public.config%rowtype;
  v_cupom  public.cupons%rowtype;
  v_qtd    int;
  v_itens  jsonb := '[]'::jsonb;
  v_sub    bigint := 0;
  v_desc   bigint := 0;
  v_frete  bigint := 0;
  v_comb   boolean := false;
  v_total  bigint;
  v_pedido public.pedidos%rowtype;
begin
  if length(v_nome) < 3 or length(v_nome) > 120 then raise exception 'Informe seu nome completo.'; end if;
  if length(v_tel) <> 11 or substr(v_tel, 3, 1) <> '9' then raise exception 'Informe um celular válido com DDD.'; end if;
  if v_tipo not in ('entrega','retirada') then raise exception 'Tipo de entrega inválido.'; end if;
  if v_forma not in ('pix','cartao_entrega','dinheiro') then raise exception 'Forma de pagamento inválida.'; end if;
  if jsonb_typeof(p->'itens') is distinct from 'array'
     or jsonb_array_length(p->'itens') = 0
     or jsonb_array_length(p->'itens') > 30 then
    raise exception 'Carrinho inválido.';
  end if;
  if v_tipo = 'entrega' then
    if length(v_cep) <> 8
       or length(btrim(coalesce(p->>'logradouro', ''))) < 2
       or length(btrim(coalesce(p->>'numero_end', ''))) < 1
       or length(btrim(coalesce(p->>'cidade', ''))) < 2
       or length(v_uf) <> 2 then
      raise exception 'Endereço de entrega incompleto.';
    end if;
  end if;

  for v_item in select value from jsonb_array_elements(p->'itens') order by value->>'produto_id' loop
    v_qtd := (v_item->>'quantidade')::int;
    if v_qtd is null or v_qtd < 1 or v_qtd > 50 then raise exception 'Quantidade inválida.'; end if;
    select * into v_prod from public.produtos where id = (v_item->>'produto_id')::uuid and ativo for update;
    if not found then raise exception 'Um dos produtos não está mais disponível.'; end if;
    if v_prod.estoque < v_qtd then raise exception 'Estoque insuficiente para: %', v_prod.nome; end if;
    update public.produtos set estoque = estoque - v_qtd where id = v_prod.id;
    v_sub := v_sub + v_prod.preco_centavos::bigint * v_qtd;
    v_itens := v_itens || jsonb_build_object('produto_id', v_prod.id, 'nome', v_prod.nome,
                                             'preco_unit_centavos', v_prod.preco_centavos, 'quantidade', v_qtd);
  end loop;

  if v_cod <> '' then
    select * into v_cupom from public.cupons
     where codigo = v_cod and ativo and (validade is null or validade >= current_date)
       and (usos_max is null or usos < usos_max) for update;
    if not found then raise exception 'Cupom inválido ou expirado.'; end if;
    if v_sub < v_cupom.minimo_centavos then raise exception 'O cupom não vale para o valor deste pedido.'; end if;
    v_desc := case when v_cupom.tipo = 'percentual' then round(v_sub * v_cupom.valor / 100.0) else least(v_cupom.valor, v_sub) end;
    update public.cupons set usos = usos + 1 where id = v_cupom.id;
  end if;

  select * into v_cfg from public.config where id = 1;
  if v_tipo = 'entrega' then
    if v_cfg.frete_fixo_centavos is null then
      v_comb := true;
    elsif v_cfg.frete_gratis_acima_centavos is not null and (v_sub - v_desc) >= v_cfg.frete_gratis_acima_centavos then
      v_frete := 0;
    else
      v_frete := v_cfg.frete_fixo_centavos;
    end if;
  end if;
  v_total := v_sub - v_desc + v_frete;

  insert into public.pedidos (cliente_nome, cliente_telefone, tipo_entrega, cep, logradouro, numero_end, complemento,
                              bairro, cidade, uf, observacoes, itens, subtotal_centavos, desconto_centavos, frete_centavos,
                              frete_a_combinar, cupom_codigo, total_centavos, forma_pagamento)
  values (v_nome, '55' || v_tel, v_tipo,
          case when v_tipo = 'entrega' then v_cep end,
          case when v_tipo = 'entrega' then left(btrim(p->>'logradouro'), 160) end,
          case when v_tipo = 'entrega' then left(btrim(p->>'numero_end'), 20) end,
          case when v_tipo = 'entrega' then left(nullif(btrim(coalesce(p->>'complemento','')), ''), 80) end,
          case when v_tipo = 'entrega' then left(nullif(btrim(coalesce(p->>'bairro','')), ''), 80) end,
          case when v_tipo = 'entrega' then left(btrim(p->>'cidade'), 80) end,
          case when v_tipo = 'entrega' then v_uf end,
          left(nullif(btrim(coalesce(p->>'observacoes','')), ''), 500),
          v_itens, v_sub, v_desc, v_frete, v_comb, nullif(v_cod, ''), v_total, v_forma)
  returning * into v_pedido;

  insert into public.pedido_eventos (pedido_id, status, por) values (v_pedido.id, 'recebido', 'cliente');
  return jsonb_build_object('numero', v_pedido.numero, 'subtotal_centavos', v_sub, 'desconto_centavos', v_desc,
                            'frete_centavos', v_frete, 'frete_a_combinar', v_comb, 'total_centavos', v_total, 'itens', v_itens);
end $$;

-- ---------- CLIENTE: acompanha o pedido (precisa do número + celular usado no pedido) ----------
create or replace function public.consultar_pedido(p_numero bigint, p_telefone text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_tel text := regexp_replace(coalesce(p_telefone, ''), '\D', '', 'g');
  v_p   public.pedidos%rowtype;
begin
  if length(v_tel) < 11 then return null; end if;
  select * into v_p from public.pedidos where numero = p_numero and right(cliente_telefone, 11) = right(v_tel, 11);
  if not found then return null; end if;
  return jsonb_build_object(
    'numero', v_p.numero, 'status', v_p.status, 'pagamento_status', v_p.pagamento_status,
    'tipo_entrega', v_p.tipo_entrega, 'total_centavos', v_p.total_centavos, 'criado_em', v_p.criado_em,
    'itens', (select coalesce(jsonb_agg(jsonb_build_object('nome', i->>'nome', 'quantidade', (i->>'quantidade')::int)), '[]'::jsonb)
                from jsonb_array_elements(v_p.itens) i),
    'eventos', (select coalesce(jsonb_agg(jsonb_build_object('status', e.status, 'criado_em', e.criado_em) order by e.criado_em, e.id), '[]'::jsonb)
                  from public.pedido_eventos e where e.pedido_id = v_p.id));
end $$;

-- ---------- ADMIN: muda etapa / confirma pagamento / cancela (devolvendo o estoque) ----------
create or replace function public.atualizar_status_pedido(p_id uuid, p_status text, p_pago boolean default null)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_ped  public.pedidos%rowtype;
  v_item jsonb;
  v_nome text;
begin
  if not public.is_admin() then raise exception 'Acesso negado.'; end if;
  if p_status not in ('recebido','confirmado','separacao','embalagem','enviado','entregue','cancelado') then
    raise exception 'Etapa inválida.';
  end if;
  select * into v_ped from public.pedidos where id = p_id for update;
  if not found then raise exception 'Pedido não encontrado.'; end if;
  if v_ped.status in ('entregue','cancelado') and p_status <> v_ped.status then
    raise exception 'Este pedido já foi encerrado.';
  end if;
  v_nome := (select nome from public.admins where user_id = auth.uid());

  -- cancelar devolve o estoque (uma única vez)
  if p_status = 'cancelado' and v_ped.status <> 'cancelado' then
    for v_item in select value from jsonb_array_elements(v_ped.itens) loop
      update public.produtos set estoque = estoque + (v_item->>'quantidade')::int
       where id = (v_item->>'produto_id')::uuid;
    end loop;
  end if;

  update public.pedidos
     set status = p_status,
         pagamento_status = case when p_pago is true then 'pago' else pagamento_status end,
         atualizado_em = now()
   where id = p_id;

  if p_status <> v_ped.status then
    insert into public.pedido_eventos (pedido_id, status, por) values (p_id, p_status, v_nome);
  end if;
  if p_pago is true and v_ped.pagamento_status = 'pendente' then
    insert into public.pedido_eventos (pedido_id, status, por) values (p_id, 'pago', v_nome);
  end if;
end $$;

-- ---------- ADMIN: gerenciar administradores ----------
drop function if exists public.adicionar_admin(text, text);
create or replace function public.adicionar_admin(p_email text, p_nome text)
returns text language plpgsql security definer set search_path = public as $$
declare v_uid uuid; v_confirmado timestamptz; v_email text := lower(btrim(coalesce(p_email, '')));
begin
  if not public.is_admin() then raise exception 'Acesso negado.'; end if;
  if v_email !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then raise exception 'E-mail inválido.'; end if;
  if length(btrim(coalesce(p_nome, ''))) < 2 then raise exception 'Informe o nome da pessoa.'; end if;
  select id, email_confirmed_at into v_uid, v_confirmado from auth.users where lower(email) = v_email;
  if v_uid is not null and v_confirmado is not null then
    insert into public.admins (user_id, nome, email) values (v_uid, btrim(p_nome), v_email)
    on conflict (user_id) do update set nome = excluded.nome, email = excluded.email;
    delete from public.admin_convites where email = v_email;
    return 'adicionado';
  end if;
  -- ainda não tem conta (ou não verificou o e-mail): deixa o convite guardado
  insert into public.admin_convites (email, nome) values (v_email, btrim(p_nome))
  on conflict (email) do update set nome = excluded.nome;
  return 'convite';
end $$;

-- chamada pelo próprio site quando alguém entra: se o e-mail (já verificado) tem convite, vira administrador
create or replace function public.reivindicar_admin()
returns boolean language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_email text; v_conf timestamptz; v_nome text; v_meta jsonb; v_usuario text;
begin
  if v_uid is null then return false; end if;
  select lower(email), email_confirmed_at, raw_user_meta_data into v_email, v_conf, v_meta from auth.users where id = v_uid;
  if v_conf is null then return false; end if;
  select nome into v_nome from public.admin_convites where email = v_email;
  if v_nome is null then return false; end if;
  v_usuario := lower(btrim(coalesce(v_meta->>'usuario', '')));
  if v_usuario !~ '^[a-z0-9._-]{3,30}$' then v_usuario := null; end if;
  if v_usuario is not null and exists (select 1 from public.admins where lower(usuario) = v_usuario and user_id <> v_uid) then v_usuario := null; end if;
  insert into public.admins (user_id, nome, email, usuario) values (v_uid, v_nome, v_email, v_usuario)
  on conflict (user_id) do nothing;
  delete from public.admin_convites where email = v_email;
  return true;
end $$;

-- a loja já tem administrador? (a tela de login usa isto para mostrar o aviso de "primeiro acesso")
create or replace function public.status_instalacao()
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object('tem_admin', exists (select 1 from public.admins));
$$;

-- confere o "nome da conta" digitado no login (quem ainda não definiu um nome passa direto)
create or replace function public.conferir_usuario(p_usuario text)
returns boolean language plpgsql security definer set search_path = public as $$
declare v text;
begin
  if not public.is_admin() then return false; end if;
  select usuario into v from public.admins where user_id = auth.uid();
  return v is null or lower(v) = lower(btrim(coalesce(p_usuario, '')));
end $$;

-- o administrador define/troca o próprio nome de conta
create or replace function public.definir_usuario(p_usuario text)
returns void language plpgsql security definer set search_path = public as $$
declare v text := lower(btrim(coalesce(p_usuario, '')));
begin
  if not public.is_admin() then raise exception 'Acesso negado.'; end if;
  if v !~ '^[a-z0-9._-]{3,30}$' then raise exception 'Use de 3 a 30 caracteres: letras minúsculas, números, ponto, hífen ou sublinhado.'; end if;
  if exists (select 1 from public.admins where lower(usuario) = v and user_id <> auth.uid()) then raise exception 'Esse nome de conta já está em uso.'; end if;
  update public.admins set usuario = v where user_id = auth.uid();
end $$;

drop function if exists public.listar_admins();
create or replace function public.listar_admins()
returns table (user_id uuid, nome text, email text, verificado boolean, criado_em timestamptz, usuario text)
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'Acesso negado.'; end if;
  return query
    select a.user_id, a.nome, a.email, (u.email_confirmed_at is not null), a.criado_em, a.usuario
      from public.admins a left join auth.users u on u.id = a.user_id
     order by a.criado_em;
end $$;

create or replace function public.remover_admin(p_user_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'Acesso negado.'; end if;
  if p_user_id = auth.uid() then raise exception 'Você não pode remover o próprio acesso.'; end if;
  if (select count(*) from public.admins) <= 1 then raise exception 'É preciso manter ao menos um administrador.'; end if;
  delete from public.admins where user_id = p_user_id;
end $$;

revoke all on function public.criar_pedido(jsonb)                       from public;
revoke all on function public.validar_cupom(text,bigint)                 from public;
revoke all on function public.consultar_pedido(bigint,text)              from public;
revoke all on function public.listar_admins()                            from public;
revoke all on function public.atualizar_status_pedido(uuid,text,boolean) from public;
revoke all on function public.adicionar_admin(text,text)                from public;
revoke all on function public.remover_admin(uuid)                       from public;
revoke all on function public.is_admin()                                from public;
revoke all on function public.reivindicar_admin()                        from public;
revoke all on function public.status_instalacao()                        from public;
revoke all on function public.conferir_usuario(text)                     from public;
revoke all on function public.definir_usuario(text)                      from public;
grant execute on function public.criar_pedido(jsonb)                       to anon, authenticated;
grant execute on function public.validar_cupom(text,bigint)                 to anon, authenticated;
grant execute on function public.consultar_pedido(bigint,text)              to anon, authenticated;
grant execute on function public.listar_admins()                            to authenticated;
grant execute on function public.atualizar_status_pedido(uuid,text,boolean) to authenticated;
grant execute on function public.adicionar_admin(text,text)                to authenticated;
grant execute on function public.remover_admin(uuid)                       to authenticated;
grant execute on function public.is_admin()                                to anon, authenticated;
grant execute on function public.reivindicar_admin()                        to authenticated;
grant execute on function public.status_instalacao()                        to anon, authenticated;
grant execute on function public.conferir_usuario(text)                     to authenticated;
grant execute on function public.definir_usuario(text)                      to authenticated;

-- ---------- FOTOS (Storage) ----------
insert into storage.buckets (id, name, public) values ('imagens', 'imagens', true)
on conflict (id) do update set public = true;

drop policy if exists imagens_leitura on storage.objects;
drop policy if exists imagens_envia   on storage.objects;
drop policy if exists imagens_edita   on storage.objects;
drop policy if exists imagens_apaga   on storage.objects;
create policy imagens_leitura on storage.objects for select using (bucket_id = 'imagens');
create policy imagens_envia   on storage.objects for insert to authenticated with check (bucket_id = 'imagens' and public.is_admin());
create policy imagens_edita   on storage.objects for update to authenticated using (bucket_id = 'imagens' and public.is_admin());
create policy imagens_apaga   on storage.objects for delete to authenticated using (bucket_id = 'imagens' and public.is_admin());

-- ---------- PRODUTOS DE EXEMPLO (só entram se a tabela estiver vazia) ----------
insert into public.produtos (categoria, nome, volume_ml, preco_centavos, estoque, destaque, notas_prova, descricao)
select * from (values
  ('vinhos',  'Vinho Tinto Reserva Pep',                750, 12000, 18, true,  'Frutas vermelhas maduras, chocolate e baunilha. Taninos macios, final persistente.', 'Vinho artesanal de pequena safra, maturado em carvalho. Harmoniza com queijos curados e carnes assadas.'),
  ('vinhos',  'Vinho Branco Colheita Pep',              750,  9800, 14, false, 'Cítrico e floral, com final fresco e leve mineralidade.', 'Vinho branco leve, colhido no ponto certo para acompanhar peixes e massas.'),
  ('vinhos',  'Vinho Rosé Estação',                     750, 10500,  9, true,  'Frutas vermelhas frescas, final leve e refrescante.', 'Rosé de produção limitada, ideal para dias quentes e encontros ao ar livre.'),
  ('azeites', 'Azeite Extravirgem Primeira Prensagem',  500,  7500, 24, true,  'Verde intenso, notas de folha de oliveira e amêndoa. Leve amargor e picância final — sinais de frescor.', 'Colhido e prensado no mesmo dia, em pequenos lotes.'),
  ('azeites', 'Azeite Aromatizado com Ervas',           250,  5200, 20, false, 'Alecrim e alho levemente tostado.', 'Azeite artesanal aromatizado com ervas do próprio rancho — ótimo para finalizar pratos.'),
  ('kits',    'Kit Degustação — Vinho + Azeite',       null, 18000, 10, true,  'A combinação perfeita para presentear: os dois carros-chefe do rancho.', 'Um vinho tinto reserva (750 ml) + um azeite extravirgem (500 ml) em caixa presente.')
) as v(categoria, nome, volume_ml, preco_centavos, estoque, destaque, notas_prova, descricao)
where not exists (select 1 from public.produtos);

insert into public.cupons (codigo, tipo, valor, minimo_centavos, ativo)
values ('BEMVINDO10', 'percentual', 10, 0, false) on conflict (codigo) do nothing;

-- =====================================================================
-- PRONTO. O banco está instalado.
-- Para criar o primeiro administrador, o assistente do site (/#admin) já
-- acrescenta no fim deste texto uma linha assim (você não precisa fazer nada):
--
--   insert into public.admin_convites (email, nome) values ('dono@email.com', 'Nome do dono')
--   on conflict (email) do update set nome = excluded.nome;
--
-- Depois é só abrir o site em /#admin > "Criar meu acesso" e confirmar o e-mail.
-- =====================================================================

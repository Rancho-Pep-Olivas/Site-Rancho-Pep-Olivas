# Rancho Pep Olivas — loja de vinhos e azeites

Um único arquivo de site (`index.html`) + banco no **Supabase** (plano gratuito) + hospedagem na **Vercel** (grátis).
Não precisa instalar nada nem editar código: o próprio site tem um **assistente de instalação** em `/#admin`.

Quem não é da área técnica: leia o **GUIA-DO-DONO.md**.

## Arquivos
- `index.html` — a loja inteira (catálogo, carrinho, checkout, painel, assistente). O SQL do banco vai embutido nele.
- `supabase-schema.sql` — o mesmo SQL, caso queira rodar à mão. O assistente já entrega esse SQL pronto (com o seu e-mail de dono).
- `vercel.json` — cabeçalhos de segurança.
- `emails/` — modelos de e-mail (confirmação, nova senha, convite) com a cara da loja; o de confirmação também mostra um código. Veja `emails/LEIA-ME.md`.

## Como a conexão funciona
- O site precisa de 2 valores do Supabase: **Project URL** e chave **anon public** (pública por natureza; a segurança está nas regras do banco — Row Level Security).
- O assistente grava os valores no navegador (`localStorage`, chave `rpo_conexao`) e, no passo 4, entrega um `index.html` com as linhas `EMBUTIDO_URL` / `EMBUTIDO_KEY` preenchidas, para valer a todos os visitantes.
- Prioridade: valor gravado no navegador > valor embutido no arquivo. "Trocar de conta" limpa o do navegador.
- Nunca use a chave `service_role` / `secret` (o assistente a recusa).

## Administradores e login
O login pede **nome da conta + e-mail + senha**. O nome da conta é conferido pela função `conferir_usuario()` logo após a senha; é uma camada extra de "algo que só o dono sabe", **não** substitui senha forte (a conferência é feita pelo site; quem falar direto com a API do Supabase continua protegido só por e-mail+senha e pelas regras RLS). Para proteção de verdade a mais, ligue MFA (TOTP) no Supabase.
A tela de login detecta sozinha quando a loja ainda **não tem nenhum administrador** (`status_instalacao()`) e mostra o aviso de "primeiro acesso".
Tabela `admin_convites` guarda e-mails autorizados. Quando a pessoa cria a conta e **verifica o e-mail**, a função `reivindicar_admin()` a transforma em administrador. Sem convite + e-mail verificado não há acesso, mesmo com cadastro aberto no Supabase.

## Publicar
GitHub (repositório com estes arquivos) → Vercel (*Add New → Project*, Framework **Other**, Deploy). Depois de mudar o `index.html` no GitHub a Vercel republica sozinha.

## Alternativa sem baixar arquivo (avançada)
Na Vercel, o `index.html` pode receber a URL/chave por variáveis de ambiente com um *Build Command* que troque as duas linhas `EMBUTIDO_*` (ex.: `sed`). Útil se preferir configurar só pelo painel da Vercel.

## Cuidados
- Plano gratuito do Supabase pode pausar projetos sem uso: clique em *Restore*.
- E-mails de confirmação do Supabase têm limite por hora; para volume maior configure SMTP próprio.
- Faça backup (painel → Configurações) e exporte pedidos em CSV de vez em quando.
- Pagamento por PIX é copia-e-cola com confirmação manual; não há cobrança automática de cartão.

## Como foi testado
- SQL executado duas vezes seguidas em PostgreSQL real (com o ambiente do Supabase simulado) e lógica de convite/administrador verificada (dono não verificado, dono verificado, intruso, adicionar equipe).
- Assistente testado em navegador simulado (jsdom): sem configuração, chave secreta bloqueada, chave inválida, banco sem tabelas, login e criação de acesso.
- **Não** foi testado contra um Supabase real nem o envio real de e-mails. Se algo falhar, o assistente mostra a mensagem; o console do navegador (F12) mostra detalhes.

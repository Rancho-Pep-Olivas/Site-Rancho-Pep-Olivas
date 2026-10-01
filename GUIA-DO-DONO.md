# Rancho Pep Olivas — colocando a loja para funcionar

São **3 coisas** e nenhuma delas exige mexer em código. Tempo total: uns 15 minutos.
O site guia você: tudo acontece na tela **`/#admin`** (no rodapé do site: "Painel administrativo").

> A conta do banco (Supabase) deve ser **do dono da loja** — é onde ficam guardados pedidos, clientes e produtos.

## 1) Criar o projeto no Supabase
1. Entre em **supabase.com** com o e-mail do dono → **New project**.
2. Nome `rancho-pep-olivas`, crie uma senha forte (guarde), região **South America (São Paulo)**.
3. Espere uns 2 minutos. Depois vá em **Project Settings → API** e deixe a página aberta (você vai copiar a *Project URL* e a chave *anon public*).

## 2) Seguir o assistente do site
Abra o site, vá em **`/#admin`**. O assistente aparece sozinho:
1. **Conectar** — cole a *Project URL* e a chave *anon public*. (O site recusa a chave secreta de propósito.)
2. **Banco** — digite seu nome e e-mail, clique **Copiar SQL**, abra o editor do Supabase pelo botão, cole e clique **Run**. Volte e clique "Já rodei, verificar".
3. **Seu acesso** — antes, no Supabase, em *Authentication → URL Configuration*, cole o endereço do site em **Site URL** e o mesmo endereço terminando em `/**` em **Redirect URLs** (o assistente mostra os dois com botão de copiar). Depois escolha o **nome da conta** e a senha, e confirme o e-mail (clicando no botão **ou** digitando o código que vem nele).

Pronto: você entra no painel. Em **Configurações** coloque o WhatsApp e a chave PIX; em **Produtos**, as fotos e preços reais.

## 3) Publicar para os clientes (uma vez só)
Os passos acima deixam a loja funcionando **no seu navegador**. Para o cliente, no celular dele, ver a loja ligada ao banco:
1. No painel: **Configurações → Conexão com o banco → Baixar index.html pronto**.
2. No **GitHub**, abra o repositório → **Add file → Upload files** → arraste o `index.html` → **Commit changes**.
3. A Vercel atualiza sozinha em cerca de 1 minuto.

## Depois disso
- **Entrar no painel:** o login pede **nome da conta**, e-mail e senha. Dá para trocar o nome da conta em Equipe → Minha conta.
- **Mais administradores:** painel → **Equipe** → nome e e-mail. A pessoa abre `/#admin` → "fui convidado(a) — criar meu acesso", escolhe o nome da conta e confirma o e-mail. Não precisa mexer no Supabase.
- **E-mails bonitos:** veja a pasta `emails/` (ou o passo 3b do assistente). É opcional.
- **O link do e-mail deu erro / "expirou":** use o código de 6 números do e-mail, ou peça outro e-mail. Se nada funcionar, no Supabase abra o *SQL Editor* e rode: `update auth.users set email_confirmed_at = now() where email = 'SEU@EMAIL.com';`
- **Trocar de conta do Supabase:** painel → Configurações → *Baixar backup* → *Trocar de conta* → refaça o assistente → *Restaurar backup* → publique de novo (passo 3).
- **Se o Supabase pausar** (plano grátis, projeto parado por semanas): entre no supabase.com e clique em *Restore*. Os dados não se perdem.
- **Pagamento:** o PIX é "copia e cola" com a sua chave; a confirmação é manual (botão *Confirmar pagamento* no pedido).

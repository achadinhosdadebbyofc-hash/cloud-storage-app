# CLOUD STORAGE APP — AI APP STUDIO

Starter web responsivo com Supabase Auth + Supabase Storage privado.

## Recursos incluídos
- Login, cadastro e logout.
- Dashboard com contagem de arquivos e uso aproximado; meta de cota lógica configurada em 500 GiB.
- Upload múltiplo e arrastar/soltar.
- Pastas de primeiro nível.
- Biblioteca de imagens, vídeos, áudios e documentos.
- Miniaturas de imagens e visualização de vídeo/áudio.
- Busca, filtros por tipo, grade/lista e favoritos.
- Download com URL assinada temporária.
- Link de compartilhamento temporário de 24 horas.
- Exclusão lógica de metadados.

## Configuração
1. Crie um projeto em https://supabase.com/.
2. Execute `supabase/schema.sql` no SQL Editor.
3. Copie `.env.example` para `.env`.
4. Preencha `VITE_SUPABASE_URL` e `VITE_SUPABASE_ANON_KEY` com URL e chave anon/publishable do projeto.
5. Execute `npm install` e `npm run dev`.

Use somente a chave anon/publishable no frontend. Nunca exponha a chave `service_role`.

## Importante — estado real
Este pacote contém código de aplicação preparado para conectar ao Supabase, mas não contém credenciais e não provisiona automaticamente uma conta, projeto ou bucket na sua nuvem. A conexão só fica ativa depois de configurar as variáveis e executar o SQL.

O link de compartilhamento desta primeira versão é uma URL assinada de 24 horas. Para links persistentes com revogação, quotas reais, lixeira com remoção de objetos, verificação server-side, antivírus, upload retomável/multipart e sincronização offline, implemente endpoints/backend e workers adicionais antes de uso em produção. A configuração VITE_STORAGE_QUOTA_GB=500 define uma cota lógica de 500 GiB na aplicação, com trigger SQL sobre os metadados. Isso não compra nem provisiona 500 GB no Supabase: a capacidade real, limites por arquivo, tráfego e cobrança dependem do plano e da configuração do projeto Supabase. O bucket permanece privado e o app gera URLs assinadas temporárias.

## Configuração escolhida
- Provedor: Supabase.
- Capacidade-alvo: 500 GiB por conta (cota lógica do app).
- Acesso: privado; bucket não público, leitura via URL assinada.
- O frontend impede uploads que ultrapassem a cota estimada e o trigger SQL valida a soma dos metadados. Para um ambiente de produção com múltiplos clientes/API externos, adicione Edge Function para upload autorizado e reconciliação periódica dos objetos no Storage; políticas Storage por si só não sincronizam o tamanho real dos objetos com a tabela `assets`.

# Checklist de Envio para Verificação Google OAuth

Projeto Google Cloud/Firebase: `study-hub-app-fddd3`  
Pacote Android: `com.victor.study_hub`  
Repositório esperado para GitHub Pages: `vilitor/study-hub`

## URLs públicas para usar após publicar GitHub Pages

- Página inicial: `https://vilitor.github.io/study-hub/`
- Política de Privacidade: `https://vilitor.github.io/study-hub/privacy.html`
- Termos de Uso: `https://vilitor.github.io/study-hub/terms.html`
- Suporte/contato: `mailto:victorfds07@gmail.com`

## Campos da tela de consentimento OAuth

- Nome do app: `Study Hub`
- E-mail de suporte do usuário: `victorfds07@gmail.com`
- Logo do app: usar a marca pública do Study Hub, consistente com o APK.
- Domínio autorizado: `vilitor.github.io`
- Página inicial do app: `https://vilitor.github.io/study-hub/`
- Política de Privacidade: `https://vilitor.github.io/study-hub/privacy.html`
- Termos de Uso: `https://vilitor.github.io/study-hub/terms.html`
- E-mail de contato do desenvolvedor: `victorfds07@gmail.com`

## Escopos solicitados

- `openid`
- `email`
- `profile`
- `https://www.googleapis.com/auth/calendar.events`

## Justificativa do escopo Calendar

O Study Hub usa Google Calendar somente quando o usuário conecta a integração e cria eventos de estudo dentro do app. O escopo `calendar.events` permite criar, atualizar e excluir eventos relacionados ao planejamento de estudos. O app não solicita o escopo amplo `calendar`, não gerencia calendários completos e não acessa dados de calendário sem ação/autorização do usuário.

Texto sugerido para o formulário:

> O Study Hub solicita acesso a eventos do Google Calendar para sincronizar eventos de estudo criados pelo usuário no app. A integração permite criar e excluir eventos de estudo no calendário do usuário quando ele escolhe usar essa função. O app não usa esse escopo para ler calendários completos, vender dados ou operar fora do contexto de planejamento de estudos.

## Roteiro do vídeo de demonstração

1. Abrir o APK release do Study Hub.
2. Fazer login com Google.
3. Mostrar a tela de onboarding e seleção de perfil de estudo.
4. Entrar no app e abrir Configurações.
5. Mostrar a seção Google Calendar conectada.
6. Criar um evento de estudo no Study Hub.
7. Abrir o Google Calendar e mostrar o evento criado.
8. Voltar ao Study Hub e excluir o evento.
9. Abrir o Google Calendar e confirmar que o evento foi removido.
10. Abrir a tela “Privacidade e dados”.
11. Mostrar exportação de dados, personalização da Luma e exclusão da conta do app.
12. Explicar que a exclusão da conta do app não exclui Conta Google, Notion nem eventos externos fora do fluxo do app.

## Screenshots recomendados

- Tela de login Google.
- Onboarding/perfil de estudo.
- Tela principal com categorias personalizadas.
- Tela de criação de evento.
- Evento criado no Google Calendar.
- Tela de Configurações com Google Calendar.
- Tela “Privacidade e dados”.
- Modal de exclusão da conta do app.

## Passos manuais no Google Cloud

1. Confirmar projeto ativo: `study-hub-app-fddd3`.
2. Confirmar que a Google Calendar API está habilitada.
3. Confirmar OAuth consent screen como External, se o app for usado fora da organização.
4. Adicionar `vilitor.github.io` como domínio autorizado.
5. Verificar propriedade do domínio no Google Search Console, se exigido.
6. Inserir URLs públicos da home, política e termos.
7. Confirmar que o Android OAuth client usa o pacote `com.victor.study_hub` e o SHA do APK release.
8. Confirmar que o Web OAuth client usado como `serverClientId` segue ativo.
9. Adicionar testadores enquanto o app estiver em modo Testing.
10. Enviar o app para verificação com vídeo e screenshots.

## Pontos de revisão antes do envio

- Não incluir `.env`, tokens, keystore, `key.properties`, exports locais ou logs privados no repositório.
- Confirmar que a política publicada é igual ou mais completa que a política do app.
- Confirmar que a tela de privacidade do app mostra exportação, exclusão e controles da Luma.
- Confirmar que o app solicita apenas `calendar.events` para Calendar.
- Confirmar que login, criação de evento, exclusão de evento e exclusão de conta funcionam no APK release.

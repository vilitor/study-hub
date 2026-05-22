# Checklist de Verificação Google OAuth

Projeto: `study-hub-app-fddd3`
Pacote Android: `com.victor.study_hub`
Conta ativa de administração: `victorfds07@gmail.com`

## Escopos solicitados

- `openid`, `email`, `profile`: escopos básicos de login Google usados pelo Google Sign-In/Firebase Auth.
- `https://www.googleapis.com/auth/calendar.events`: permite visualizar e editar eventos em calendários do usuário para criar, atualizar e excluir eventos do Study Hub.

## Justificativa dos escopos

O app usa Google Calendar somente para sincronizar eventos criados/gerenciados pelo usuário no Study Hub. O escopo amplo `https://www.googleapis.com/auth/calendar` não deve ser solicitado porque permite gerenciar calendários completos e não é necessário para o produto.

## Itens obrigatórios antes de enviar

- Nome público do app: Study Hub.
- Logo pública consistente com o app.
- URL pública da home page do app.
- URL pública da Política de Privacidade.
- URL pública dos Termos de Uso.
- E-mail de suporte.
- E-mail de contato do desenvolvedor.
- Domínio autorizado verificado no Google Search Console.
- Tela de consentimento OAuth preenchida com descrição clara do app.
- Lista de testadores configurada enquanto o app estiver em modo Testing.
- APK release assinado com SHA cadastrado no Firebase/Google Cloud.

## Roteiro de vídeo demonstrativo

1. Abrir o app e entrar com Google.
2. Mostrar onboarding/perfil de estudo.
3. Abrir Configurações e mostrar Google Calendar conectado.
4. Criar um evento no Study Hub.
5. Abrir Google Calendar e demonstrar o evento criado.
6. Excluir o evento no Study Hub.
7. Confirmar remoção no Google Calendar.
8. Abrir Privacidade e dados, mostrar exportação, Luma local-first e exclusão da conta do app.

## Evidências recomendadas

- Screenshot da tela de login.
- Screenshot do onboarding.
- Screenshot da tela de Configurações.
- Screenshot da tela Privacidade e dados.
- Screenshot do evento no Google Calendar.
- Screenshot da confirmação de exclusão da conta do app.

## Status de produção

- APIs habilitadas: Calendar API, Firebase, Firestore e Identity Toolkit.
- Verificar antes do envio: domínio público, política/termos hospedados, suporte público e consent screen em produção.

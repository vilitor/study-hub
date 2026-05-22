# Política de Privacidade do Study Hub

Última atualização: 21 de maio de 2026

Esta Política de Privacidade explica como o Study Hub trata dados pessoais e dados de uso do aplicativo. O Study Hub é um aplicativo local-first para organização de estudos, metas, eventos, registros, certificados e integrações opcionais com Firebase, Google Calendar e Notion.

## Controlador e contato

Controlador: Study Hub
Contato de privacidade/suporte: definir e-mail público antes da publicação
Projeto Firebase: `study-hub-app-fddd3`

## Dados tratados

O app pode tratar os seguintes dados, conforme o uso:

- Dados de login Google: identificador Firebase, e-mail, nome e foto de perfil quando o usuário entra com Google.
- Dados de estudo: registros, tempos de estudo, matérias/categorias, notas inseridas pelo usuário, metas, eventos e histórico.
- Dados de configuração: tema, lembretes, perfil de estudo, preferências de onboarding, campos locais, categorias personalizadas e status de sincronização.
- Certificados/conquistas: certificados cadastrados, links/anexos escolhidos pelo usuário e progresso de conquistas.
- Integração Google Calendar: eventos criados, atualizados ou excluídos pelo app quando o usuário autoriza a integração.
- Integração Notion: token do Notion, identificador de database e schema em cache quando o usuário conecta uma tabela.
- Luma: mensagens da conversa local atual e contexto de estudos usado localmente quando a personalização está ativada.

## Onde os dados ficam armazenados

O Study Hub salva dados primeiro no dispositivo. Para usuários autenticados, o backup Firebase grava dados do app em `users/{uid}` no Firestore. Dados de visitante permanecem locais. Tokens sensíveis, como token do Notion, são armazenados no armazenamento seguro do dispositivo.

## Google Calendar

O app solicita o escopo `https://www.googleapis.com/auth/calendar.events` para criar, editar e excluir eventos de calendário relacionados ao uso do Study Hub. O app não solicita acesso amplo para gerenciar calendários completos.

## Notion

A conexão com Notion é opcional. O token é usado apenas para sincronizar dados com a tabela informada pelo usuário. O app não exclui a conta Notion e não compartilha o token com terceiros.

## Luma

A Luma V1 é local-first e não envia dados para API externa de IA. A personalização pode ser desativada nas configurações, e a memória/conversa local da Luma pode ser limpa pelo usuário.

## Exclusão e exportação

O usuário pode exportar seus dados em JSON pelo app. A opção “Excluir conta do app” remove dados do Study Hub associados ao usuário no Firebase, limpa dados locais da conta ativa, limpa filas de sincronização e encerra a sessão. Essa ação não exclui a Conta Google, a conta Notion nem eventos externos do Google Calendar.

## Retenção

Dados locais permanecem no dispositivo até o usuário apagar os dados do app, limpar a conta, excluir a conta do app ou desinstalar o aplicativo. Dados em nuvem permanecem no Firestore enquanto o usuário mantiver o backup ativo e não excluir a conta do app.

## Direitos do titular

Nos termos da LGPD, o usuário pode solicitar confirmação de tratamento, acesso, correção, portabilidade, eliminação, informação sobre compartilhamento e revogação de consentimento. Os controles principais estão disponíveis no próprio aplicativo; solicitações adicionais devem ser enviadas ao canal de contato publicado.

## Compartilhamento

O Study Hub não vende dados pessoais. Dados são enviados apenas aos serviços escolhidos pelo usuário: Firebase para backup, Google Calendar para eventos e Notion para sincronização de tabela.

## Segurança

O app usa autenticação Firebase, isolamento por UID no Firestore, armazenamento seguro para tokens locais e regras de acesso que restringem dados ao próprio usuário autenticado.

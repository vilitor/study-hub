# Mapa de Dados do Study Hub

| Tipo de dado | Local de armazenamento | Local/Nuvem | Escopo | Retenção | Controle do usuário |
|---|---|---|---|---|---|
| Tema claro/escuro | SharedPreferences | Local | Global do dispositivo | Até alteração/desinstalação | Alterar em Configurações |
| Registros de estudo | SharedPreferences e Firestore `users/{uid}/studyLogs` | Local e nuvem autenticada | `guest` ou `uid:<uid>` | Até exclusão | Editar, excluir, exportar |
| Eventos | SharedPreferences, Firestore `studyEvents`, Google Calendar opcional | Local/nuvem/externo | `guest` ou `uid:<uid>` | Até exclusão | Criar, excluir, sincronizar |
| Metas | SharedPreferences e Firestore `goals` | Local e nuvem autenticada | `guest` ou `uid:<uid>` | Até exclusão | Criar, excluir, exportar |
| Certificados/conquistas | SharedPreferences e Firestore `certificates` | Local e nuvem autenticada | `guest` ou `uid:<uid>` | Até exclusão | Criar, excluir, exportar |
| Perfil de estudo/onboarding | SharedPreferences e Firestore `settings/app` | Local e nuvem autenticada | `guest` ou `uid:<uid>` | Até exclusão | Reconfigurar parcialmente, excluir conta |
| Categorias/esquema local | SharedPreferences e Firestore `localConfig` | Local e nuvem autenticada | `guest` ou `uid:<uid>` | Até exclusão | Editar campos/categorias |
| Token Notion | Flutter Secure Storage | Local seguro | `guest` ou `uid:<uid>` | Até desconectar/excluir | Conectar/desconectar |
| Database ID Notion | Secure Storage/backup de configuração | Local e nuvem autenticada | `guest` ou `uid:<uid>` | Até desconectar/excluir | Conectar/desconectar |
| Dados de perfil Google | Secure Storage e Firestore doc do usuário | Local e nuvem autenticada | `uid:<uid>` | Até logout/exclusão | Desconectar/excluir conta |
| Fila de sync | SharedPreferences | Local | `guest` ou `uid:<uid>` | Até sincronizar/limpar | Sincronizar/excluir conta |
| Luma conversa atual | Memória do app | Local em memória | Sessão ativa | Até limpar/reiniciar/resetar conta | Limpar memória, desativar personalização |

Nenhum dado de visitante deve ser enviado ao Firestore. Nenhum dado de uma conta `uid:<uid>` deve ser lido ou exibido em outra conta.

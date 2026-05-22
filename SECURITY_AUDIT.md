# Auditoria de Segurança e Privacidade

Data: 21 de maio de 2026

## Resumo

O Study Hub usa arquitetura local-first, Firebase Auth, Firestore por usuário, Google Calendar opcional, Notion opcional e Luma local-first. A auditoria confirmou isolamento por namespace no armazenamento local e regras Firestore baseadas em `request.auth.uid`.

## Achados corrigidos nesta revisão

- Escopo Google Calendar reduzido para `calendar.events`.
- Regras Firestore endurecidas para coleções conhecidas sob `users/{uid}` e bloqueio de caminhos inesperados.
- Tela “Privacidade e dados” ampliada com transparência local/nuvem, exportação JSON e controles da Luma.
- Preferência de personalização da Luma persistida por namespace de conta.
- Logs ajustados para não registrar título de evento nem ID de página Notion em sucesso de arquivamento.
- Documentação LGPD/OAuth/dados criada.

## Dados coletados

Dados de login Google, dados de estudo, metas, eventos, certificados, configurações, categorias, integração Notion opcional, eventos Google Calendar opcionais e contexto local usado pela Luma.

## Permissões Android

- `INTERNET`: necessária para Firebase, Google Calendar, Notion e GitHub updater.
- `REQUEST_INSTALL_PACKAGES`: usada pelo GitHub updater para instalação de APK pelo usuário. Deve ser justificada na política/descrição do app e removida se o updater externo for removido.

## OAuth

O escopo amplo `calendar` foi removido. O escopo remanescente `calendar.events` é sensível e exige justificativa na verificação OAuth.

## Firebase

As regras Firestore agora permitem acesso apenas ao próprio `users/{uid}` e às coleções esperadas. Não há acesso público amplo. App Check ainda não está configurado/enforced.

## App Check

Recomendação: configurar Firebase App Check com Play Integrity para Android, registrar o SHA-256 release e monitorar métricas antes de ativar enforcement. Não ativar enforcement antes de validar APK release, builds de teste e distribuição fora da Play Store, para evitar bloqueio de usuários legítimos.

## Logs e segredos

Não foram encontrados logs imprimindo OAuth access token, id token, token Notion ou payload completo do usuário. Logs devem continuar limitados a estados, códigos e IDs técnicos não sensíveis.

## Pendências antes de publicação

- Hospedar política de privacidade, termos e home page em domínio público.
- Preencher e verificar OAuth consent screen.
- Definir e-mail público de suporte/privacidade.
- Configurar App Check em modo monitoramento.
- Revisar juridicamente a política e os termos.

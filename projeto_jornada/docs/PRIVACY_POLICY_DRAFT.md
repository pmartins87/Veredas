# Política de Privacidade — Veredas da Trama

> **RASCUNHO DE PRÉ-LANÇAMENTO — NÃO PUBLICAR COMO VERSÃO FINAL ENQUANTO HOUVER CAMPOS `PENDING_*`.**

**Última revisão do rascunho:** 12 de agosto de 2026  
**Aplicativo:** Veredas da Trama  
**Android application ID:** `com.pmartins87.veredasdatrama`

## 1. Responsável e contato

Veredas da Trama é desenvolvido e publicado pelo responsável identificado na página oficial do aplicativo.

**Contato de privacidade:** `PENDING_PRIVACY_CONTACT`

Este campo deve ser substituído por um canal público e monitorado antes do lançamento.

## 2. Princípio de minimização de dados

O jogo foi projetado para funcionar prioritariamente de forma offline. Progresso, configurações, histórico de jornada, desbloqueios e saves são armazenados no dispositivo do jogador e, por si só, não são enviados ao desenvolvedor.

A versão de lançamento não pretende usar publicidade, rastreamento publicitário, SDK de analytics, conta própria do jogo, acesso a localização, contatos, câmera, microfone ou dados de saúde.

A permissão de internet do aplicativo é usada pelo faturamento da plataforma e pelo fluxo HTTPS de verificação de compras descrito abaixo; ela não transforma saves ou gameplay em dados de nuvem.

## 3. Compras e titularidades

O modelo comercial planejado usa compras digitais não consumíveis processadas pelo Google Play Billing. Dados de pagamento, como número de cartão ou conta bancária, são fornecidos diretamente ao provedor de pagamento e não são acessados nem armazenados pelo jogo.

Para confirmar uma compra ou restaurar uma titularidade, o aplicativo envia ao backend de verificação um envelope técnico limitado contendo identificador da requisição de verificação, identificador do aplicativo/pacote, identificador do produto, token de compra, horário informado da compra e estado de acknowledgement conhecido pelo cliente. O fluxo não inclui perfil de gameplay, save, histórico de combate, localização, contatos ou identificadores publicitários.

O token de compra é necessário de forma transitória para que o backend consulte a compra correspondente na Google Play Android Developer API. Na implementação de referência preparada para produção, **o token de compra bruto não é persistido pelo backend**. A chave persistente de deduplicação é um hash SHA-256 do token. Também não é necessário persistir `orderId` para conceder titularidade.

O registro de backend é limitado ao hash do token e a estado técnico mínimo da compra/titularidade, como pacote, produto, estado da compra, estado de acknowledgement, indicador de titularidade, estágio de processamento, horário de conclusão informado pelo Google quando disponível, indicador de compra de teste e timestamps do servidor.

A titularidade nova só deve ser concedida depois que o backend confirmar a compra com o Google Play e, quando necessário, realizar e confirmar o acknowledgement. Uma compra pendente, cancelada, incompatível ou não verificável não deve conceder uma nova titularidade.

## 4. Finalidades

Os dados técnicos de compra são usados somente para:

- confirmar que uma compra digital corresponde ao aplicativo e ao produto esperado;
- conceder, restaurar ou revogar a titularidade correspondente;
- impedir reutilização do mesmo token para produto diferente;
- reconhecer com segurança uma compra já processada;
- realizar/confirmar acknowledgement quando necessário;
- diagnosticar falhas de restauração ou faturamento quando indispensável à finalidade acima.

Dados de compra não são usados para publicidade comportamental, criação de perfil de gameplay ou venda de perfis de usuário.

## 5. Serviços de terceiros e infraestrutura

O lançamento planeja integrar o **Google Play Billing** para processar compras digitais e a **Google Play Android Developer API** para verificar compras no servidor. O Google opera seus próprios sistemas e políticas para dados processados por seus serviços.

A implementação de referência do backend usa infraestrutura de servidor separada do APK/AAB. O código de backend é explicitamente excluído dos artefatos Android. A autenticação do backend perante o Google é projetada para usar uma identidade de serviço anexada ao ambiente de execução, sem arquivo de chave de service account incorporado ao aplicativo ou à imagem do servidor.

O armazenamento de referência para o registro técnico mínimo de deduplicação/titularidade é o Google Cloud Firestore. A infraestrutura de produção, região, endpoint, identidade de serviço e configuração final ainda precisam ser congelados antes do lançamento.

**Inventário final de SDKs/serviços:** `PENDING_FINAL_SDK_AUDIT`

Nenhum SDK ou serviço adicional deve ser incluído na versão final sem revisão desta Política e da declaração de Segurança dos dados do Google Play.

## 6. Armazenamento local

O jogo mantém localmente dados necessários à experiência, como perfil, saves, progresso, configurações e cache de titularidades. A remoção do aplicativo ou a limpeza dos dados do aplicativo pelo sistema operacional pode remover esses dados locais, ressalvadas eventuais funções de backup/restauração fornecidas pelo sistema ou pela plataforma.

Uma titularidade previamente verificada pode permanecer disponível por meio do cache local durante falhas temporárias de loja/backend, de acordo com a implementação final. Uma falha temporária de comunicação não deve transformar uma compra nova não verificada em titularidade.

## 7. Retenção e exclusão

Dados exclusivamente locais permanecem no dispositivo até que sejam sobrescritos, apagados pelo próprio funcionamento do jogo, removidos pelo usuário ou eliminados com os dados do aplicativo, conforme o comportamento do sistema operacional.

O backend de referência evita persistir o token de compra bruto e o `orderId`; mantém um hash SHA-256 do token e o estado técnico mínimo necessário para deduplicação, restauração/revogação e integridade da titularidade. A política de produção deverá definir por quanto tempo esse registro mínimo é retido, os fundamentos operacionais/legais aplicáveis e o mecanismo de exclusão quando cabível.

**Política final de retenção e exclusão do backend de compras:** `PENDING_12_3_12_4_RETENTION_POLICY`

## 8. Segurança

O projeto adota minimização de dados e separa credenciais de assinatura e identidades/segredos de produção do código do aplicativo. O fluxo de verificação usa HTTPS. O aplicativo não incorpora uma credencial reutilizável capaz de autorizar titularidades; a decisão depende da verificação autoritativa da compra no servidor.

O backend de referência usa associação transacional entre o hash do token e o produto e só retorna titularidade positiva depois de confirmar estado `PURCHASED` e acknowledgement. Antes da publicação ainda deverão ser congelados controles de abuso/rate limit e permissões mínimas da identidade de serviço.

## 9. Crianças e público-alvo

**Classificação etária e declaração de público-alvo:** `PENDING_STORE_CONTENT_RATING`

Antes da publicação, este trecho deverá ser alinhado à classificação indicativa e às declarações de público-alvo preenchidas na loja.

## 10. Alterações desta Política

A Política poderá ser atualizada quando funcionalidades, serviços, requisitos legais ou práticas de dados mudarem. A versão publicada exibirá uma data de vigência e deverá permanecer consistente com o comportamento efetivo do aplicativo, backend e declarações da loja.

## 11. Acesso à Política

Antes do lançamento, a versão final será disponibilizada em URL pública, estável e não editável por usuários, além de ficar acessível a partir do próprio aplicativo.

**URL pública final:** `PENDING_PUBLIC_URL`

---

# Privacy Policy — Veredas da Trama

> **PRE-RELEASE DRAFT — DO NOT PUBLISH AS FINAL WHILE ANY `PENDING_*` FIELD REMAINS.**

**Draft last reviewed:** August 12, 2026  
**App:** Veredas da Trama  
**Android application ID:** `com.pmartins87.veredasdatrama`

## 1. Controller / publisher and contact

Veredas da Trama is developed and published by the responsible party identified on the app's official page.

**Privacy contact:** `PENDING_PRIVACY_CONTACT`

This field must be replaced by a public, monitored contact before launch.

## 2. Data minimization

The game is designed to work primarily offline. Progress, settings, journey history, unlocks, and save data are stored on the player's device and are not, by themselves, sent to the developer.

The planned launch version does not intend to use advertising, advertising tracking, an analytics SDK, a proprietary game account, or access to location, contacts, camera, microphone, or health data.

The app's internet permission is used for platform billing and the HTTPS purchase-verification flow described below; it does not turn save files or gameplay into cloud data.

## 3. Purchases and entitlements

The planned commercial model uses non-consumable digital purchases processed through Google Play Billing. Payment data such as card or bank-account information is provided directly to the payment provider and is not accessed or stored by the game.

To verify a purchase or restore an entitlement, the app sends a limited technical envelope to the verification backend containing a verification request ID, app/package ID, product ID, purchase token, client-reported purchase time, and client-known acknowledgement state. The verification flow does not include the gameplay profile, save data, combat history, location, contacts, or advertising identifiers.

The raw purchase token is transiently needed so that the backend can query the matching purchase through the Google Play Android Developer API. In the production reference implementation, **the backend does not persist the raw purchase token**. Its durable deduplication key is a SHA-256 hash of that token. An `orderId` is not required to grant the entitlement and is not part of the reference persistent record.

The reference backend stores only the token hash and minimum purchase/entitlement state: package, product, purchase state, acknowledgement state, ownership flag, processing stage, Google-reported completion time when available, test-purchase flag, and server timestamps.

A new entitlement must only be granted after the backend verifies the purchase with Google Play and, where required, performs and confirms acknowledgement. A pending, cancelled, mismatched, or unverifiable purchase must not grant a new entitlement.

## 4. Purposes

Purchase-related technical data is used only to:

- verify that a digital purchase belongs to the expected app and product;
- grant, restore, or revoke the corresponding entitlement;
- prevent the same token from being rebound to a different product;
- safely recognize a purchase that has already been processed;
- perform/confirm acknowledgement where needed;
- diagnose restore or billing failures where necessary for those purposes.

Purchase data is not used for behavioral advertising, gameplay profiling, or sale of user profiles.

## 5. Third-party services and infrastructure

The launch plans to use **Google Play Billing** for digital purchases and the **Google Play Android Developer API** for server-side purchase verification. Google operates its own systems and policies for data handled by its services.

The reference verification backend runs separately from the APK/AAB, and backend source is explicitly excluded from Android artifacts. The backend is designed to authenticate to Google through a service identity attached to the runtime environment, without embedding a service-account key file in the app or server image.

Google Cloud Firestore is the reference store for the minimum technical deduplication/entitlement record. The final production infrastructure, region, endpoint, service identity, and configuration must still be frozen before release.

**Final SDK/service inventory:** `PENDING_FINAL_SDK_AUDIT`

No additional SDK or service may be added to the final build without reviewing this Policy and the Google Play Data safety declaration.

## 6. Local storage

The game locally stores data needed for the experience, including profile, saves, progress, settings, and the entitlement cache. Uninstalling the app or clearing its app data may remove local data, subject to any backup/restore behavior actually provided by the operating system or platform.

A previously verified entitlement may remain available from the local cache during a temporary store/backend outage, according to the final implementation. Temporary loss of connectivity must not turn a new unverified purchase into an entitlement.

## 7. Retention and deletion

Device-only data remains on the device until it is overwritten, removed by game behavior, deleted by the user, or removed with the app's data as determined by the operating system.

The reference backend avoids persisting the raw purchase token and `orderId`; it retains a SHA-256 token hash and the minimum technical state needed for deduplication, restoration/revocation, and entitlement integrity. The production policy must define how long this minimum record is retained, the applicable operational/legal grounds, and the deletion mechanism where applicable.

**Final purchase-backend retention and deletion policy:** `PENDING_12_3_12_4_RETENTION_POLICY`

## 8. Security

The project applies data minimization and keeps signing credentials and production identities/secrets out of the application code. Purchase verification uses HTTPS. The app does not embed a reusable credential capable of authorizing an entitlement; entitlement decisions depend on authoritative server-side purchase verification.

The reference backend transactionally binds the token hash to a product and only returns positive ownership after confirming `PURCHASED` state and acknowledgement. Production abuse/rate-limit controls and least-privilege service permissions must still be frozen before launch.

## 9. Children and target audience

**Content rating and target-audience declaration:** `PENDING_STORE_CONTENT_RATING`

Before publication, this section must be aligned with the final rating and target-audience declarations in the store.

## 10. Changes to this Policy

This Policy may be updated when features, services, legal requirements, or data practices change. The published version will include an effective date and must remain consistent with the actual app/backend behavior and store declarations.

## 11. Access to the Policy

Before launch, the final version will be made available through a stable public URL that users cannot edit and will also remain accessible from within the app.

**Final public URL:** `PENDING_PUBLIC_URL`

# Política de Privacidade — Veredas da Trama

> **RASCUNHO DE PRÉ-LANÇAMENTO — NÃO PUBLICAR COMO VERSÃO FINAL ENQUANTO HOUVER CAMPOS `PENDING_*`.**

**Última revisão do rascunho:** 13 de agosto de 2026  
**Aplicativo:** Veredas da Trama  
**Android application ID:** `com.pmartins87.veredasdatrama`

## 1. Responsável e contato

Veredas da Trama é desenvolvido e publicado pelo responsável identificado na página oficial do aplicativo.

**Contato de privacidade:** `PENDING_PRIVACY_CONTACT`

Este campo será substituído por um canal público e monitorado antes do lançamento.

## 2. Minimização e funcionamento offline

O jogo foi projetado para funcionar prioritariamente offline. Perfil, progresso, configurações, histórico de jornada e saves permanecem no dispositivo e, por si só, não são enviados ao desenvolvedor.

A versão planejada para lançamento não usa publicidade, rastreamento publicitário, SDK próprio de analytics, conta própria do jogo nem acesso a localização, contatos, câmera, microfone ou dados de saúde.

A permissão de internet é usada pelo Google Play Billing e pelo fluxo HTTPS de verificação de compras. Ela não transforma saves ou gameplay em dados de nuvem.

## 3. Compras e titularidades

As compras digitais não consumíveis são processadas pelo Google Play Billing. O jogo não acessa nem armazena número de cartão ou conta bancária.

Para confirmar uma compra ou restaurar uma titularidade, o aplicativo envia ao backend de verificação apenas um envelope técnico de Billing: identificador da requisição, pacote do aplicativo, produto, token de compra, horário informado da compra e estado de acknowledgement conhecido pelo cliente. Esse fluxo não inclui perfil de gameplay, save, histórico de combate, localização, contatos ou identificadores publicitários.

O token de compra bruto existe somente de forma transitória durante a verificação. O cache local não o persiste: mantém uma referência `sha256:<digest>` e o estado mínimo da titularidade. Referências antigas de desenvolvimento em formato bruto são convertidas para SHA-256 durante a normalização antes de o perfil voltar a ser armazenado.

O backend também não persiste o token bruto nem `orderId`. O identificador durável é o SHA-256 do token. O registro contém somente pacote, produto, estado da compra, acknowledgement, titularidade, estágio de processamento, horário de conclusão quando disponível, indicador de compra de teste, timestamps do servidor e `expires_at`.

Uma nova titularidade só é concedida depois de verificação autoritativa com o Google Play, acknowledgement quando necessário e persistência final bem-sucedida. Estado PENDING, cancelado, incompatível, não verificável ou falha de persistência nunca concede uma nova titularidade.

## 4. Finalidades

Os dados técnicos de Billing são usados somente para verificar compras, conceder/restaurar/revogar titularidades, impedir associação indevida do mesmo token a outro produto, reconhecer processamento anterior, realizar acknowledgement e diagnosticar falhas de faturamento/restauração quando necessário.

Eles não são usados para publicidade comportamental, perfil de gameplay ou venda de perfis de usuário.

## 5. Serviços de terceiros e infraestrutura

O lançamento planeja usar **Google Play Billing**, **Google Play Android Developer API**, **Google Cloud Run** e **Google Cloud Firestore**. O backend roda separado do APK/AAB e seu código é excluído dos artefatos Android.

A autenticação servidor→Google usa identidade de serviço anexada ao ambiente de execução por Application Default Credentials; nenhuma chave de service account é incorporada ao aplicativo ou à imagem do backend.

**Inventário final de SDKs/serviços:** `PENDING_FINAL_SDK_AUDIT`

Nenhum SDK ou serviço adicional deve ser incluído no release sem nova revisão da política e da declaração de Segurança dos dados.

## 6. Armazenamento local

Perfil, saves, progresso, configurações e cache de titularidades permanecem localmente. Desinstalar ou limpar os dados do aplicativo pode removê-los, ressalvado o comportamento efetivo de backup/restauração do sistema ou plataforma.

O cache de titularidade usa schema interno 2 e armazena somente estado técnico e uma referência SHA-256 da compra; o token bruto não faz parte desse cache. A auditoria do AAB, save e caminho de backup reais continua obrigatória antes do release.

Uma titularidade já verificada pode continuar disponível pelo cache local durante indisponibilidade temporária da loja/backend. Falha temporária nunca transforma uma compra nova não verificada em titularidade.

## 7. Retenção e exclusão

Dados exclusivamente locais permanecem no dispositivo até serem sobrescritos, removidos pelo funcionamento do jogo, apagados pelo usuário ou eliminados junto com os dados do aplicativo.

O backend mantém apenas o hash SHA-256 do token e o estado técnico mínimo descrito acima. A política implementada é finita e baseada na última atividade do registro:

- compra real `PURCHASED` e `owned=true`: **730 dias** desde a última atividade no backend;
- registro bound, PENDING, CANCELLED ou de outra forma sem titularidade ativa: **30 dias** desde a última atividade;
- compra marcada como teste: **7 dias** desde a última atividade, inclusive se estiver em estado PURCHASED.

Cada verificação/binding legítimo renova `expires_at` segundo o estado efetivo mais recente, sem permitir que uma observação atrasada regrida o estado transacional da compra. O campo `expires_at` é destinado a uma política TTL do Firestore. A exclusão TTL é assíncrona e pode ocorrer depois do instante de expiração; a configuração efetiva do TTL será verificada na infraestrutura de produção antes do lançamento.

A expiração do cache do backend não concede, revoga nem prova titularidade. Se um registro já tiver expirado e uma compra reaparecer posteriormente, o backend precisa fazer nova verificação autoritativa com o Google Play antes de recriar o registro ou retornar titularidade positiva.

## 8. Segurança

O projeto aplica minimização, HTTPS, separação de segredos e associação transacional token-hash→produto. O backend grava estado de forma monotônica, só retorna `owned=true` após confirmação autoritativa/acknowledgement/persistência final e converte indisponibilidade de Google/Firestore em falha controlada, nunca em titularidade positiva.

Controles finais de rate limit, permissões mínimas e configuração de produção ainda precisam ser congelados e auditados.

## 9. Crianças e público-alvo

**Classificação etária e declaração de público-alvo:** `PENDING_STORE_CONTENT_RATING`

Este trecho será alinhado à classificação e às declarações efetivamente submetidas à loja antes da publicação.

## 10. Alterações desta Política

A versão publicada exibirá data de vigência e permanecerá consistente com o comportamento efetivo do aplicativo, backend e declarações da loja. Mudanças de SDK, rede, publicidade, analytics, conta ou fluxo de dados exigem nova auditoria.

## 11. Acesso à Política

Antes do lançamento, a versão final será disponibilizada em URL pública estável e dentro do próprio aplicativo.

**URL pública final:** `PENDING_PUBLIC_URL`

---

# Privacy Policy — Veredas da Trama

> **PRE-RELEASE DRAFT — DO NOT PUBLISH AS FINAL WHILE ANY `PENDING_*` FIELD REMAINS.**

**Draft last reviewed:** August 13, 2026  
**App:** Veredas da Trama  
**Android application ID:** `com.pmartins87.veredasdatrama`

## 1. Controller / publisher and contact

Veredas da Trama is developed and published by the responsible party identified on the app's official page.

**Privacy contact:** `PENDING_PRIVACY_CONTACT`

This will be replaced by a public monitored contact before launch.

## 2. Data minimization and offline behavior

The game is designed to work primarily offline. Profile, progress, settings, journey history, and save data remain on the device and are not, by themselves, sent to the developer.

The planned launch does not use advertising, advertising tracking, a developer analytics SDK, a proprietary game account, or access to location, contacts, camera, microphone, or health data.

Internet permission is used by Google Play Billing and the HTTPS purchase-verification flow. It does not turn saves or gameplay into cloud data.

## 3. Purchases and entitlements

Non-consumable digital purchases are processed by Google Play Billing. The game does not access or store payment-card or bank-account information.

To verify a purchase or restore an entitlement, the app sends only a limited Billing envelope to the verification backend: verification request ID, app package, product, purchase token, client-reported purchase time, and client-known acknowledgement state. Gameplay profile, save data, combat history, location, contacts, and advertising identifiers are excluded.

The raw purchase token exists only transiently during verification. The local cache does not persist it; it keeps a `sha256:<digest>` reference and minimum entitlement state. Legacy development references in raw form are converted to SHA-256 during normalization before the profile is stored again.

The backend also does not persist the raw token or `orderId`. Its durable identifier is the token SHA-256. The minimum record contains package, product, purchase state, acknowledgement state, ownership, processing stage, completion time when available, test-purchase flag, server timestamps, and `expires_at`.

A new entitlement is granted only after authoritative Google Play verification, acknowledgement where required, and successful final persistence. PENDING, cancelled, mismatched, unverifiable purchases, or persistence failure never grant a new entitlement.

## 4. Purposes

Billing technical data is used only to verify purchases, grant/restore/revoke entitlements, prevent an existing token from being rebound to another product, recognize prior processing, perform acknowledgement, and diagnose billing/restore failures when necessary.

It is not used for behavioral advertising, gameplay profiling, or sale of user profiles.

## 5. Third-party services and infrastructure

The planned launch uses **Google Play Billing**, the **Google Play Android Developer API**, **Google Cloud Run**, and **Google Cloud Firestore**. The backend runs separately from the APK/AAB and its source is excluded from Android artifacts.

Server-to-Google authentication uses a runtime-attached service identity through Application Default Credentials; no service-account key is embedded in the app or backend image.

**Final SDK/service inventory:** `PENDING_FINAL_SDK_AUDIT`

No additional SDK or service may enter the release without reviewing this Policy and the Google Play Data safety declaration.

## 6. Local storage

Profile, saves, progress, settings, and entitlement cache remain local. Uninstalling or clearing app data may remove them, subject to the actual backup/restore behavior of the OS or platform.

The entitlement cache uses internal schema 2 and stores only technical state plus a SHA-256 purchase reference; the raw token is not part of that cache. Final AAB, real-save, and backup-path audit remains mandatory before release.

A previously verified entitlement may remain available from local cache during a temporary store/backend outage. Temporary failure never converts a new unverified purchase into an entitlement.

## 7. Retention and deletion

Device-only data remains on the device until overwritten, removed by game behavior, deleted by the user, or removed with the app's data.

The backend keeps only the purchase-token SHA-256 and the minimum technical state described above. The implemented policy is finite and based on the record's last backend activity:

- real `PURCHASED` purchase with `owned=true`: **730 days** from last activity;
- bound, PENDING, CANCELLED, or otherwise non-owned record: **30 days** from last activity;
- test purchase: **7 days** from last activity, including when PURCHASED.

Each legitimate verification/binding refreshes `expires_at` according to the effective current state without allowing a late observation to regress transactional purchase state. `expires_at` is intended for a Firestore TTL policy. TTL deletion is asynchronous and can occur after the expiry instant; effective production TTL configuration will be verified before launch.

Expiry of the backend cache does not grant, revoke, or prove an entitlement. If an expired purchase appears again, the backend must perform a fresh authoritative Google Play verification before recreating the record or returning positive ownership.

## 8. Security

The project uses data minimization, HTTPS, secret separation, and transactional token-hash→product binding. Purchase state is monotonic, `owned=true` is returned only after authoritative verification/acknowledgement/final persistence, and Google/Firestore outages fail closed rather than grant ownership.

Final rate limiting, least-privilege permissions, and production configuration still require freeze and audit.

## 9. Children and target audience

**Content rating and target-audience declaration:** `PENDING_STORE_CONTENT_RATING`

This section will be aligned with the rating and target-audience declarations actually submitted to the store before publication.

## 10. Changes to this Policy

The published version will carry an effective date and remain consistent with the actual app, backend, and store declarations. Changes to SDKs, network behavior, advertising, analytics, accounts, or data flows require renewed review.

## 11. Access to the Policy

Before launch, the final version will be available through a stable public URL and from inside the app.

**Final public URL:** `PENDING_PUBLIC_URL`

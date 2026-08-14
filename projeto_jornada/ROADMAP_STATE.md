# Veredas da Trama — Estado Canônico do Roadmap

## Identidade e contrato de estado
- Título: **Veredas da Trama**.
- Sem referências no produto ao jogo externo usado como inspiração inicial.
- Direção visual: livro-jogo ilustrado à mão, nanquim/grafite, papel orgânico e paletas próprias dos 12 Domínios.
- Roadmap detalhado: `ROADMAP_MASTER.md`.
- `✅` exige gate/evidência real persistida; `🟡` é implementação/preflight/evidência pendente; `⏳` é ainda não iniciado.
- Preparar código, workflow ou contrato **não aumenta a contagem formal**.

## Contagem formal
**110/130 passos concluídos.**

## Escopo de lançamento
- Idiomas: **pt_BR + en**; `es_419` preservado e adiado.
- Android application ID: **`com.pmartins87.veredasdatrama`**.
- Ponto final: **12.10 — projeto/build completos, testados e prontos para jogar, divulgar e publicar**.

## Fases 0–6
- **0.1–6.10: 10/10 ✅ em cada fase.**

## Fase 7 — Assets finais
- 7.1 ✅; 7.2 ✅; 7.3 🟡; 7.4 🟡; 7.5 🟡; 7.6 ✅; 7.7 ✅; 7.8 🟡; 7.9 ✅; 7.10 ⏳.
- 7.3–7.5: ilustrações finais de Domínios/localidades, personagens/NPCs e monstros/chefes.
- 7.8: áudio/música finais (`DEP-078-AUDIO`).
- 7.10 depende dos assets finais 7.3–7.5/7.8.

## Fases 8–10
- **8.1–8.10 ✅**.
- **9.1–9.10 ✅**.
- **10.1–10.10 ✅ e congelada**, com `BALANCE_FREEZE.json` e gates estatísticos/canônicos.

## Fase 11 — QA, otimização e localização
- 11.1 ✅ — regressão/integração ampla; 288 jornadas completas.
- 11.2 ✅ — fuzzing/migração/corrupção de saves.
- 11.3 🟡 — automação/emuladores verdes; falta soak físico >=1.800 s (`DEP-113-PHYSICAL`).
- 11.4 ✅ — responsividade/acessibilidade.
- 11.5 ✅ — arquitetura de localização; fonte/fallback `pt_BR`, launch `pt_BR + en`.
- 11.6 🟡 — pack inglês físico íntegro; **131/131 pt_BR + 131/131 en** na UI; faltam pack/glossário/arquitetura/linguística/overflow/iconografia/regressões no mesmo HEAD.
- 11.7 🟡 — QA audiovisual real; faltam assets finais, incluindo 38 referências de áudio.
- 11.8 ✅ — zero blocker/critical ativo; `BILL-124-001` descoberto depois foi corrigido e permanece resolved.
- 11.9 🟡 — 128 pause/resume + 24 restart rounds preparados; execução real pendente.
- 11.10 🟡 — freeze RC depende de 11.3/11.6/11.7/11.9. O workflow exige versão pública congelada antes do PASS, usa Godot 4.7.1 cujo binário Linux é verificado pelo SHA-256 oficial e só emite evidência após todos os gates + árvore limpa. O artifact contém `QA_11_10_COMPLETION.json` **e** `QA_11_10_RELEASE_INPUT_MANIFEST.json`: o completion registra o HEAD certificado e o aggregate SHA-256 de todos os inputs runtime/build. Mudança posterior de código, conteúdo, versão, preset ou qualquer input fingerprintado exige novo 11.10; commits posteriores somente de evidência/console são aceitos se o fingerprint continuar byte-identical.

### Infraestrutura de execução
GitHub Actions continua apresentando falha anterior ao primeiro step: último probe observado com `runner_id=0`, `steps=[]`, nome/grupo de runner vazios. Isso **não é PASS nem FAIL do código**. Não gastar interações rerodando executor inexistente sem indício de recuperação.

## Fase 12 — Publicação e release
Nenhum passo da Fase 12 está formalmente concluído; **12.1–12.10 seguem 🟡**.

### 12.1 🟡 — nome/identidade
Candidato **Veredas da Trama**. Duas rodadas de reconnaissance pública não encontraram colisão exata indexada relevante, mas isso não é clearance jurídico. INPI/WIPO interativos, domínios/handles e decisão final de marca seguem pendentes.

### 12.2 🟡 — package/versionamento/assinatura/toolchain
- Application ID congelado em `com.pmartins87.veredasdatrama`; Godot 4.7.1, minSdk 24, compile/target API 36 e Build Tools 36.1.0.
- `mobile/release_identity.json` agora contém contrato explícito de **freeze de versão pública**: `0.1.0-dev`/code 1 continuam desenvolvimento; alvo inicial é `1.0.0`. O gate `tools/release_version_identity_gate.py --release` recusa RC/release enquanto a versão não estiver congelada em semver estável e o versionCode não tiver confirmação de estar livre no Play Console. Qualquer mudança de versão depois de 11.10 muda o fingerprint e exige novo 11.10.
- `product/release_signing_identity.json` separa **upload key** e **Play app-signing key**. Upload: RSA >=2048, certificado com janela de validade >=25 anos, keystore/segredos fora do Git e backups criptografados redundantes. App signing: chave gerenciada pelo Google Play, fingerprint SHA-256 público e validade além de 2033-10-22. Os dois certificados devem ser distintos.
- `tools/release_signing_identity_gate.py` inspeciona certificado público real, tamanho/algoritmo, janela de validade e SHA-256; material privado nunca vira evidência.
- O signer é posteriormente extraído **do próprio AAB** e precisa coincidir com o fingerprint congelado da upload key.
- `INTERNET` permanece explícito e backend excluído dos dois presets Android.
- Faltam: keystore real + backups, protected secrets, Play App Signing/registro do upload cert, fingerprints/validades reais, confirmação do versionCode livre, freeze `1.0.0`, política final e evidência de Play Console.

### 12.3 🟡 — privacidade, Data Safety, termos, classificação e plataforma
- Runtime legal PT-BR/en e drafts bilíngues implementados.
- Gameplay/save permanecem offline-first; caminho HTTP de aplicação allowlisted apenas para verificação de Billing.
- Token bruto de compra é transitório; local/backend persistem referência/hash SHA-256 + estado mínimo; `orderId` não é persistido.
- **Política de retenção do backend congelada em código e contratos:** `expires_at` + Firestore TTL; 730 dias para compra real PURCHASED/owned, 30 dias para bound/PENDING/CANCELLED/non-owned e 7 dias para compra de teste, sempre desde a última atividade legítima.
- Expiração do cache não é prova de entitlement; recriação exige nova verificação autoritativa Google Play.
- `tools/play_billing_retention_gate.py` valida código/contrato; `tools/privacy_retention_consistency_gate.py` cruza backend ↔ privacy manifest ↔ política PT/EN ↔ texto legal in-app.
- **Classificação/público-alvo:** `product/content_rating_target_audience.json`, `tools/content_rating_target_audience_gate.py`, `.github/workflows/veredas-content-rating-12-3.yml` e `CONTENT_RATING_12_3_STATE.json` foram adicionados. O preflight reconhece fantasia, combate, monstros e mecânicas de dano/derrota; cruza ausência de anúncios, assinaturas, loot boxes e recompensas aleatórias pagas com modelo comercial/privacidade/listing.
- O projeto **não prevê nem inventa uma classificação etária**. Treze categorias potencialmente relevantes — violência, sangue/gore, horror, linguagem, sexualidade/nudez, substâncias, jogo de azar, ódio/discriminação, autoagressão e outros temas maduros — continuam exigindo revisão humana do conteúdo final. O questionário IARC e suas classificações regionais devem vir do Play Console para o RC exato.
- Público-alvo é tratado separadamente da classificação: faixas finais permanecem pendentes de decisão humana. Seleção abaixo de 13 exige revisão de Famílias; seleção 13–15/16–17 exige revisão explícita de status infantil/privacidade e adequação de compra/marketing antes do release.
- As fontes textuais canônicas para essa revisão são os mesmos 14 datasets em `data/` usados pelo catálogo de localização, além dos overlays do launch pt_BR/en; ausência de keyword hit **não** será usada como prova de ausência de uma categoria.
- Permanecem pendentes: deploy real, habilitar/verificar TTL no Firestore, auditoria da persistência real/AAB, contato/URLs, revisão legal final, revisão do conteúdo final, decisão de público-alvo, questionário/certificado IARC, Data Safety, políticas e Play Console.

### 12.4 🟡 — Billing/entitlements de produção
- Cliente/runtime e backend de referência implementados fail-closed.
- ProductPurchaseV2, validação de pacote/produto/estado/quantidade/opção, ausência de offer/rent/preorder, binding token→produto, estado monotônico, acknowledgement+refetch, ADC e persistência mínima já estão implementados.
- Retenção finita 730/30/7 está implementada em `retention_policy.py`, aplicada transacionalmente em Firestore e integrada ao gate combinado 12.4.
- Permanecem: addon 3.3.0 real, produtos Play, backend HTTPS, identidade/Play API, Firestore+TTL, rate limit, execução de testes/gates e cenários reais PURCHASED/PENDING/restore/reinstall/refund/revogação/offline.

### 12.5 🟡 — store listing/ASO/assets
- Copy PT-BR/en-US pronta e coerente com desbloqueio integral + Selo de Apoiador visual-only; contagens atuais: **1319 PT-BR / 1207 en-US** na descrição completa.
- Baseline oficial Google Play rechecado em 2026-08-13. Mantemos 6 screenshots retrato 1080×1920 por idioma, excedendo a recomendação de jogos de pelo menos 3 imagens 9:16 nessa resolução mínima.
- `product/store_capture_manifest.json` define **12 capturas reais do Android RC**, todas obrigatoriamente do mesmo conteúdo/build certificado; cada PNG recebe SHA-256, timestamp UTC e identidade do device/emulador.
- `tools/finalize_store_capture_manifest.py` somente vincula metadados/hashes a PNGs já capturados e não edita pixels. `tools/store_capture_provenance_gate.py` valida o caminho inverso e rejeita mockup, RC/fingerprint divergente, hash divergente ou completion 11.10 inválido.
- `tools/store_listing_gate.py` também deixou de aceitar mera existência de completion; no release valida seu conteúdo.
- `tools/store_commercial_consistency_gate.py` prova que **listing ↔ `commercial_model.json` ↔ Billing ↔ Termos** descrevem os mesmos dois produtos não consumíveis: desbloqueio integral content-only e Selo de Apoiador `supporter_badge` visual-only, sem anúncios, assinaturas, loot boxes ou poder pago.
- Feature graphic mantém alt text padrão PT-BR e variante localizada en-US no contrato; arte final ainda não existe.
- Workflow `.github/workflows/veredas-store-listing-12-5.yml` executará os gates quando houver runner. Ainda faltam arte final do ícone/feature graphic, as 12 capturas do RC real, 12.1/12.4 finais, execução dos gates e inspeção/upload no Play Console.

### 12.6 🟡 — AAB/APK final assinado/reproduzível
- O vínculo 11.10 → AAB não depende mais de “mesmo commit literal”. O critério é **HEAD 11.10 ancestral + `QA_11_10_RELEASE_INPUT_MANIFEST.json` idêntico**. Isso permite commits administrativos posteriores de assinatura/Play sem reexecutar QA, mas qualquer mudança em código, conteúdo, versão, presets, `mobile/` ou demais inputs fingerprintados bloqueia o AAB e exige novo 11.10.
- `tools/release_rc_binding_gate.py` verifica ancestry, run ID, integridade do completion e SHA-256 do manifesto certificado. O workflow compara os inputs atuais com esse manifesto antes e depois do import/export.
- Godot Linux 4.7.1 e export templates são baixados dos releases oficiais e verificados por SHA-256; `bundletool 1.18.3` também está pinado por digest oficial.
- `tools/release_aab_identity_gate.py` lê o **manifest efetivo do AAB** com bundletool e valida applicationId, versionName/code, minSdk, targetSdk, `debuggable=false`, `INTERNET` e inventário de permissões; permissões incompatíveis com o baseline de privacidade falham fechado.
- A assinatura usa protected secrets temporários; `jarsigner -strict` valida o AAB e `keytool -printcert -jarfile` extrai o certificado do artefato, que precisa coincidir com o SHA-256 da upload key congelada.
- Fingerprint de inputs permanece acíclico; evidência de release fica fora. Inventário Android final continua previsto sobre `releaseRuntimeClasspath` no mesmo Gradle do AAB.
- Faltam: pré-requisitos 11.10/12.2–12.5 reais, addon/template Gradle final, AAB assinado real, execução dos novos gates, inventário Android persistido, rebuild equivalence, auditoria de payload e aceitação no Play Console.

### 12.7 🟡 — teste interno/fechado
Baseline: interno + fechado, >=12 testers por >=14 dias contínuos. Evidência real pendente.

### 12.8 🟡 — RC final/go-no-go/rollback
Exige 11.10 + 12.1–12.7 certificados, mesma identidade de inputs/artefato, zero blockers, dry run e decisão go/no-go.

### 12.9 🟡 — continuidade/suporte/proveniência/licenças
- 4 SVGs atuais têm blob Git + commit de introdução; revisão final de direitos pendente.
- 7 componentes conhecidos têm licença identificada em fonte primária; review/notices finais pendentes.
- Backend: pipeline de lock/SBOM resolve em Python 3.12/Linux **sem instalar tooling de evidência no venv runtime**; lê `METADATA` dos wheels com stdlib `zipfile/email`, gera hashes e prova reinstall offline com `--require-hashes`, `pip check`, freeze idêntico e imports.
- Android: inventário final captura `releaseRuntimeClasspath` do mesmo build assinado.
- `third_party_notices.json` é evidência separada do SBOM e precisa cobrir cada componente final backend/Android.
- O arquivo canônico `product/release_archive_manifest.json` exige **12 itens obrigatórios hashados**, incluindo notices de terceiros.
- Faltam runner para lock/SBOM, Gradle/addon final para inventário Android, revisão de direitos/licenças, notices completos, tag/AAB/identidade, owners/canais, backups/recovery drills, termos de serviços externos e handoff.

### 12.10 🟡 — FINAL
Somente PASS quando 12.8/12.9 e toda identidade tag/commit/version/AAB/signing/archive/smoke/store/privacy/Billing/support/rollback coincidirem, com `ready_to_play`, `ready_to_promote`, `ready_to_publish` verdadeiros e decisão `go`.

## Blockers/dependências reais
1. Aparelho físico para 11.3.
2. Executor funcional para gates reais 11.6/11.9/11.10 e suítes 12.x.
3. Assets finais de arte/áudio para Fase 7, 11.7, classificação visual/audiovisual e store assets.
4. 12.2: upload keystore + backups, protected secrets, Play App Signing, fingerprints/validades, versionCode livre e freeze público `1.0.0` antes do 11.10 final.
5. Play Console, addon Billing e AAB real.
6. Backend de produção: endpoint HTTPS, identidade/Play API, Firestore, **TTL `expires_at` habilitado/verificado**, rate limit e auditoria real.
7. Classificação/público-alvo: revisão do corpus/arte/áudio finais, faixas-alvo decididas, IARC real e eventuais revisões Famílias/menores.
8. Test track real 12.7.
9. Store 12.5: completion/fingerprint real de 11.10 + 12 screenshots Android do conteúdo certificado + icon/feature graphic finais.
10. Continuidade final: lock/SBOM, inventário Android, notices/licenças, direitos dos assets, 12 itens do arquivo, owners/recovery/handoff.
11. Due diligence final do nome e documentação pública/legal.

## Regra de avanço
- Não repetir diagnóstico de blocker conhecido sem nova evidência.
- Avançar qualquer trabalho independente que reduza risco de release.
- Nunca aumentar **110/130** por preflight; somente por PASS real persistido.

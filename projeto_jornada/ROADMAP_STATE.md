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
- 11.10 🟡 — freeze RC depende de 11.3/11.6/11.7/11.9.

### Infraestrutura de execução
GitHub Actions continua apresentando falha anterior ao primeiro step: `runner_id=0`, `steps=[]`, nome/grupo de runner vazios. Isso **não é PASS nem FAIL do código**. O último probe de Billing 12.4 nesta ancestry repetiu exatamente esse padrão. Não gastar interações rerodando executor inexistente; usar o runner apenas quando houver indício de recuperação.

## Fase 12 — Publicação e release
Nenhum passo da Fase 12 está formalmente concluído; **12.1–12.10 seguem 🟡**.

### 12.1 🟡 — nome/identidade
Candidato **Veredas da Trama**. Busca pública inicial não é clearance jurídico. INPI/WIPO, domínios/handles e decisão final de marca seguem pendentes.

### 12.2 🟡 — package/versionamento/assinatura/toolchain
- Godot 4.7.1; minSdk 24; compile/target API 36; Build Tools 36.1.0.
- `INTERNET` explícito e backend excluído dos dois presets Android.
- Faltam keystore/backup, secrets, Play Console, freeze de versão e artefato assinado real.

### 12.3 🟡 — privacidade, Data Safety, termos e plataforma
- Runtime legal PT-BR/en e drafts bilíngues implementados.
- Gameplay/save permanecem offline-first; caminho HTTP de aplicação allowlisted apenas para verificação de Billing.
- Token bruto de compra é transitório; local/backend persistem referência/hash SHA-256 + estado mínimo; `orderId` não é persistido.
- **Política de retenção do backend agora está congelada em código e contratos:** `expires_at` + Firestore TTL; 730 dias para compra real PURCHASED/owned, 30 dias para bound/PENDING/CANCELLED/non-owned e 7 dias para compra de teste, sempre desde a última atividade legítima.
- Expiração do cache não é prova de entitlement; recriação exige nova verificação autoritativa Google Play.
- `tools/play_billing_retention_gate.py` valida código/contrato; `tools/privacy_retention_consistency_gate.py` cruza backend ↔ privacy manifest ↔ política PT/EN ↔ texto legal in-app.
- Permanecem pendentes: deploy real, habilitar/verificar TTL no Firestore, auditoria da persistência real/AAB, contato/URLs, revisão legal final, rating/público-alvo, Data Safety, políticas e Play Console.

### 12.4 🟡 — Billing/entitlements de produção
- Cliente/runtime e backend de referência implementados fail-closed.
- ProductPurchaseV2, validação de pacote/produto/estado/quantidade/opção, ausência de offer/rent/preorder, binding token→produto, estado monotônico, acknowledgement+refetch, ADC e persistência mínima já estão implementados.
- Retenção finita 730/30/7 está implementada em `retention_policy.py`, aplicada transacionalmente em Firestore e integrada ao gate combinado 12.4.
- Permanecem: addon 3.3.0 real, produtos Play, backend HTTPS, identidade/Play API, Firestore+TTL, rate limit, execução de testes/gates e cenários reais PURCHASED/PENDING/restore/reinstall/refund/revogação/offline.

### 12.5 🟡 — store listing/ASO/assets
Copy PT-BR/en-US pronta e coerente com desbloqueio integral + Selo de Apoiador visual-only. Faltam arte final, screenshots reais do RC e Play Console.

### 12.6 🟡 — AAB/APK final assinado/reproduzível
- Fingerprint de inputs é acíclico: só recursos runtime reais entram; evidência de release fica fora.
- Workflow exige equivalência pre/post export.
- Inventário Android final é extraído do `releaseRuntimeClasspath` no mesmo Gradle do AAB, com SHA-256 de AAR/JAR/local e cross-check da versão Billing.
- Faltam pré-requisitos certificados, addon/template Gradle real, AAB assinado, inventário persistido, rebuild equivalence e Play acceptance.

### 12.7 🟡 — teste interno/fechado
Baseline: interno + fechado, >=12 testers por >=14 dias contínuos. Evidência real pendente.

### 12.8 🟡 — RC final/go-no-go/rollback
Exige 11.10 + 12.1–12.7 certificados, mesma identidade de artefato, zero blockers, dry run e decisão go/no-go.

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
3. Assets finais de arte/áudio para Fase 7, 11.7 e store assets.
4. Play Console, assinatura, addon Billing e AAB real.
5. Backend de produção: endpoint HTTPS, identidade/Play API, Firestore, **TTL `expires_at` habilitado/verificado**, rate limit e auditoria real.
6. Test track real 12.7.
7. Continuidade final: lock/SBOM, inventário Android, notices/licenças, direitos dos assets, 12 itens do arquivo, owners/recovery/handoff.
8. Due diligence final do nome e documentação pública/legal.

## Regra de avanço
- Não repetir diagnóstico de blocker conhecido sem nova evidência.
- Avançar qualquer trabalho independente que reduza risco de release.
- Nunca aumentar **110/130** por preflight; somente por PASS real persistido.

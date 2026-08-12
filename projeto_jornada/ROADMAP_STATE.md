# Veredas da Trama — Estado Canônico do Roadmap

## Identidade e contrato de estado
- Título oficial de trabalho: **Veredas da Trama**.
- Sem referências no produto ao jogo externo usado como inspiração inicial.
- Direção visual: livro-jogo ilustrado à mão, nanquim/grafite, papel orgânico e paletas próprias dos 12 Domínios.
- Roadmap finito detalhado: `ROADMAP_MASTER.md`.
- Este arquivo é o **índice canônico de status**, não deve duplicar relatórios extensos dos arquivos `*_STATE.json`/`*_COMPLETION.json`.
- `✅` só é usado quando o gate/evidência exigido foi realmente concluído e persistido.
- `🟡` significa implementação/preflight em andamento ou gate preparado aguardando evidência real.
- `⏳` significa ainda não iniciado estruturalmente.
- Preparar um gate **não aumenta a contagem formal**.

## Contagem formal
**110/130 passos concluídos.**

## Escopo de lançamento
- Idiomas: **pt_BR + en**.
- `es_419` permanece preservado como idioma adiado e não integra os gates do release atual.
- Android application ID: **`com.pmartins87.veredasdatrama`**.
- Ponto final permanece **12.10: projeto/build completos, testados e prontos para jogar, divulgar e publicar**.

## Fases 0–6
- **0.1–6.10: 10/10 ✅ em cada fase.**

## Fase 7 — Assets finais
- 7.1 ✅
- 7.2 ✅
- 7.3 🟡 — 12 Domínios + 120 localidades, grandes ilustrações finais.
- 7.4 🟡 — 36 personagens + NPCs, ilustrações finais.
- 7.5 🟡 — 300 monstros + 60 chefes/subchefes, ilustrações finais.
- 7.6 ✅
- 7.7 ✅
- 7.8 🟡 — áudio/música finais; dependência `DEP-078-AUDIO`.
- 7.9 ✅
- 7.10 ⏳ — QA audiovisual final; depende de 7.3–7.5 e 7.8.

## Fase 8
- **8.1–8.10 ✅ — concluída.**

## Fase 9
- **9.1–9.10 ✅ — concluída.**

## Fase 10 — Balanceamento e simulação
- **10.1–10.10 ✅ — concluída e congelada.**
- Evidência central: `BALANCE_FREEZE.json` + gates estatísticos/canônicos existentes.
- Marcos já certificados incluem matriz de personagens, inimigos, itens/economia, narrativa, quatro dificuldades, ritmo/attrition, simulações massivas e playtests adversariais.

## Fase 11 — QA, otimização e localização
- 11.1 ✅ — matriz ampla de regressão/integracão. Referência: commit `0afd8f2`; 288 jornadas completas e cenários live certificados.
- 11.2 ✅ — fuzzing/migração de saves. Referências `39a811c`/`7aec534`; migrações, rejeição de corrupção e compatibilidade certificadas.
- 11.3 🟡 — performance/memória/bateria/térmica/loading. Automação/emuladores verdes; falta aparelho físico com soak >= 1.800 s. Dependência `DEP-113-PHYSICAL`.
- 11.4 ✅ — UI responsiva/acessibilidade. Referência `c988448`; matriz de dispositivos passou.
- 11.5 ✅ — arquitetura de localização. Fonte/fallback `pt_BR`; launch `pt_BR + en`; IDs estáveis/overlays.
- 11.6 🟡 — QA linguístico/overflow/iconografia/terminologia. Pack inglês físico está íntegro (`part_000`–`part_009`, 133.572 caracteres Base64); `LOC-116-001` resolvido. Faltam execuções finais no mesmo HEAD. Estados: `LOCALIZATION_11_6_STATE.json`, `LOCALIZATION_11_6_STATUS.md`, `LOCALIZATION_11_6_PACK_CHECKPOINT.md`.
- 11.7 🟡 — QA audiovisual real. Preflight existe, mas 38 referências de áudio final e assets associados ainda bloqueiam a certificação. Estado: `AUDIOVISUAL_11_7_STATUS.md`.
- 11.8 ✅ — zero blocker/critical conhecido. `QA_11_8_COMPLETION.json`; resultado persistido: `active_blocker_critical=0`.
- 11.9 🟡 — soak/long sessions/suspend-resume/confiabilidade. Gate implementa 128 ciclos pause/resume + 24 restaurações tipo restart (152 reloads antes do roundtrip final). Estado: `RELIABILITY_11_9_STATE.json`. Execução real ainda pendente.
- 11.10 🟡 — freeze de QA/RC. Gate `tools/qa_release_candidate_gate.py`, estado `QA_11_10_STATE.json`; depende de 11.3/11.6/11.7/11.9 certificados.

### Infraestrutura de execução
GitHub Actions tem apresentado falhas de infraestrutura anteriores ao primeiro step (`runner_id=0`, `steps=[]`). Isso **não** vale como PASS ou FAIL do código. Não repetir runners mortos como substituto de progresso; avançar infraestrutura independente e executar gates reais quando houver executor/aparelho/assets.

## Fase 12 — Publicação e release
Nenhum passo da Fase 12 está formalmente concluído; **12.1–12.10 estão 🟡**, com infraestrutura preparada e evidência real progressivamente pendente.

- 12.1 🟡 — nome comercial/identidade. Candidato: **Veredas da Trama**. Estado: `RELEASE_12_1_NAME_STATE.json`. Busca pública inicial sem colisão exata relevante não equivale a clearance jurídico; INPI/WIPO/handles/domínios e decisão de marca permanecem pendentes.
- 12.2 🟡 — package ID/versionamento/assinatura/toolchain. Estado: `RELEASE_12_2_STATE.json`; identidade em `mobile/release_identity.json`; validador `tools/validate_android_export.py`. Baseline Android explicitamente congelado em Godot 4.7.1, minSdk 24, compile/target API 36 e Build Tools 36.1.0. Faltam rechecagem de política no release, keystore real/backup seguro, secrets, Play Console, freeze de versão e artefato real.
- 12.3 🟡 — privacidade/Data Safety/termos/requisitos de plataforma. Estado: `RELEASE_12_3_STATE.json`; contratos `product/privacy_data_safety.json` e `product/platform_compliance.json`; drafts `docs/PRIVACY_POLICY_DRAFT.md` e `docs/TERMS_OF_USE_DRAFT.md`; gates `tools/privacy_data_safety_gate.py` e `tools/platform_compliance_gate.py`. Faltam dados finais pós-Billing/AAB, URL/contato, fechamento dos Termos, rating/público-alvo/Data Safety e verificação real no Play Console.
- 12.4 🟡 — Billing/entitlements de produção. Contrato `mobile/play_billing_contract.json`, estado `RELEASE_12_4_STATE.json`, gate `tools/play_billing_release_gate.py`. Modelo atual: desbloqueio integral não consumível + pacote opcional de apoiador exclusivamente cosmético; `PENDING` não concede e entitlement exige verificação. Faltam plugin/backend/Play products e testes reais.
- 12.5 🟡 — store listing/ASO/assets. Copy PT-BR/en-US e gate `tools/store_listing_gate.py` preparados; copy comercial alinhada ao conjunto atual de produtos de 12.4. Faltam arte final, screenshots reais do RC e inspeção no Play Console. Estado `RELEASE_12_5_STATE.json`.
- 12.6 🟡 — AAB/APK final assinado/reproduzível. Estado `RELEASE_12_6_STATE.json`, contrato `mobile/release_artifact_contract.json`, fingerprint `tools/release_input_fingerprint.py`, workflow de AAB. Faltam pré-requisitos certificados, artefato real, assinatura/hash/fingerprint, rebuild equivalence e Play acceptance.
- 12.7 🟡 — teste interno/fechado/rollout. Estado `RELEASE_12_7_STATE.json`, plano `product/play_test_rollout_plan.json`, gate `tools/play_test_rollout_gate.py`. Baseline do projeto: track interno + fechado com >=12 testers por >=14 dias contínuos; faltam evidências reais e Billing/tester feedback/production access quando aplicável.
- 12.8 🟡 — RC final/checklist/rollback. Contrato `product/release_candidate_final_contract.json`, estado `RELEASE_12_8_STATE.json`, gate `tools/release_candidate_final_gate.py`, workflow `Veredas Final Release Candidate 12.8`. Exige 11.10 + 12.1–12.7 certificados, mesma identidade de artefato, zero blockers, dry run e go/no-go. Primeira publicação usa hotfix de versionCode maior; updates podem usar rollout 10/25/50/100; nunca downgrade.
- 12.9 🟡 — documentação/continuidade/suporte. Contrato `product/continuity_support_contract.json`, estado `RELEASE_12_9_STATE.json`, runbook `docs/CONTINUITY_AND_SUPPORT.md`, gate `tools/continuity_support_gate.py`, workflow `Veredas Continuity and Support 12.9`. Exige tag/archive final, canais/owners reais, recuperação de contas, backups externos/restoration drill, proveniência/licenças e handoff.
- 12.10 🟡 — **FINAL**. Contrato `product/final_release_contract.json`, estado `RELEASE_12_10_STATE.json`, gate `tools/final_release_gate.py`, workflow `Veredas Final Release 12.10`. Só pode PASS quando 12.8/12.9 passarem, tag/commit/version/AAB/signing/archive coincidirem, final smoke/store/privacy/Billing/support/rollback estiverem prontos e as três afirmações `ready_to_play`, `ready_to_promote`, `ready_to_publish` forem verdadeiras com decisão final `go`.

## Blockers/dependências reais ainda abertas
1. **Aparelho físico** para 11.3 e evidência operacional associada.
2. **Execução real dos gates** de 11.6/11.9 e freeze 11.10 quando houver executor funcional.
3. **Assets finais de arte e áudio**, necessários para 7.3–7.5/7.8/7.10, 11.7 e store assets.
4. **Contas/infra de publicação reais**: Play Console, assinatura/backup, Billing backend/produtos, canais de suporte/privacidade e fechamento dos documentos públicos.
5. **Test track real** de 12.7 e evidência do AAB exato.
6. **Due diligence final do nome**, política/loja e documentação pública.

## Próxima regra de avanço
- Não voltar a diagnosticar blockers já conhecidos a cada interação.
- Avançar primeiro qualquer trabalho independente ainda executável.
- Quando só restarem dependências externas, registrar explicitamente qual evidência externa desbloqueia qual gate.
- Nunca aumentar 110/130 por preflight; só por `PASS` real persistido.

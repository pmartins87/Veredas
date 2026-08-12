# Veredas da Trama — Estado Canônico do Roadmap

## Identidade
- Título oficial de trabalho: **Veredas da Trama**.
- O produto não contém referências ao jogo externo usado como inspiração inicial.
- Direção visual própria: livro-jogo ilustrado à mão, nanquim/grafite, papel orgânico e paletas dos 12 Domínios.

## Progresso formal
- Fases 0–6: **10/10 ✅ cada**.
- Fase 7: 7.1, 7.2, 7.6, 7.7 e 7.9 ✅; 7.3–7.5/7.8 em produção; 7.10 pendente.
- Fase 8: **8.1–8.10 ✅ — concluída**.
- Fase 9: **9.1–9.10 ✅ — concluída**.
- Fase 10: **10.1–10.10 ✅ — concluída e congelada**.
- Fase 11: **11.1, 11.2, 11.4, 11.5 e 11.8 ✅; 11.3 aguarda medição física; 11.6, 11.7, 11.9 e 11.10 em andamento com gates fail-closed**.
- Fase 12: **12.1, 12.2 e 12.3 em preflight antecipado; nenhum passo da Fase 12 promovido ainda**.

## Marcos QA recentes
### 11.1 — Matriz ampla de regressão e integração ✅
Commit limpo `0afd8f2`: 288 jornadas completas, 48 pares determinísticos, 0 deadlocks, 0 combat timeouts e 48/48 cenários live de evento/viagem/mercador/combate nos 12 Domínios.

### 11.2 — Fuzzing/migração de saves e compatibilidade ✅
Core `39a811c`, re-freeze `7aec534`: 192 perfis migráveis normalizados; 16/64 runs recuperáveis aceitos; 48/64 impossíveis rejeitados; 8/8 arquivos corrompidos recusados; rejeição transacional e compatibilidade Hub/RNG legado certificadas.

### 11.3 — Performance, memória, bateria, térmica e loading 🟡
Automação e emuladores verdes. O gate formal continua aguardando aparelho físico por 30 minutos.
- 11.3-A: Hub cold 40,75 ms; jornada p95 11,77 ms; save/load p95 0,84/0,88 ms; deriva 0,02 MB; node drift 0.
- 11.3-B: API 29 cold 1.715 ms / resume p95 649 ms / PSS 200,94 MB; API 34 cold 1.455 ms / resume p95 1.065 ms / PSS 192,50 MB; sem deriva relevante.
- 11.3-C pendente: `tools/android_performance_profile.sh source=physical`, soak mínimo 1.800 s.

### 11.4 — UI responsiva e acessibilidade ✅
Commit limpo `c988448`, run `31421360688`: 100 casos de cena, 80 modos dinâmicos, 1.560 checks de touch target, 2.320 tipográficos, 48 de contraste e 5 safe areas — todos PASS. A interface principal tornou-se responsiva e rolável sem reduzir fonte, contraste ou alvo mínimo de toque.

### 11.5 — Arquitetura de localização e idiomas ✅
Commit certificado `37878d1`. Arquitetura de IDs estáveis + overlays de apresentação; fonte/fallback `pt_BR`; conteúdo canônico permanece imutável para regras e balanceamento.

**Escopo de lançamento atualizado em 12/08/2026:** os idiomas do lançamento atual são **pt_BR + en**. `es_419` permanece preservado no projeto como idioma adiado para uma expansão futura e não integra os gates do release atual.

### 11.6 — QA linguístico, overflow, iconografia e terminologia 🟡
O blocker físico de packs foi removido do escopo atual, mas a etapa ainda precisa das execuções finais no mesmo HEAD.
- inventário congelado: **5.160 registros / 18.804 unidades de conteúdo localizáveis**;
- UI obrigatória: **119/119** em `pt_BR` e `en`;
- labels mecânicos/lore: **165/165** em `pt_BR` e `en`;
- glossário canônico e gates de placeholders/BBCode/terminologia/overflow/iconografia existem;
- inglês: **15.334 unidades de delta** + **3.470 unidades-base** = **18.804/18.804**;
- pack inglês físico no HEAD: `part_000`–`part_009`, contíguos, **133.572 caracteres Base64**; `part_005` atual possui 16.000 bytes;
- compilador, certifier e sanity linguístico derivam os alvos do `localization/manifest.json`;
- o quality gate mescla o pack compacto antes de verificar completude, tokens e glossário;
- overflow e iconografia/acessibilidade estão alinhados a `pt_BR + en`;
- `LOC-116-001` está **resolved** no ledger: o defeito inglês antigo foi corrigido e ES-419 saiu explicitamente do escopo do lançamento;
- ainda faltam execução do certifier inglês, glossário/token/BBCode sobre corpus completo, render/overflow, iconografia/acessibilidade, sanity linguístico e regressões no mesmo HEAD;
- nenhum desses gates será considerado PASS enquanto o runner continuar encerrando jobs antes dos steps.

### 11.7 — QA audiovisual final em contexto real 🟡
Preflight e integração foram implementados, mas assets finais continuam bloqueando a certificação.
- `AudioRouter` é autoload e está conectado ao `PresentationBus` real;
- 5 buses garantidos: Master, Music, Ambience, SFX e UI;
- contrato: **7 eventos de UI + 7 de combate + 24 camadas music/ambience dos 12 Domínios = 38 referências**;
- roteamento `location -> world_id -> Domínio` verificado contra o gerador de conteúdo;
- política `sound_supports_reading`: Music -15 dB, Ambience -18 dB, SFX -9 dB, UI -8 dB, com margem mínima de 4 dB;
- auditor Python e cena Godot de contexto real são fail-closed;
- os 38 assets finais de `res://assets/audio/**` ainda não existem no branch, portanto **7.8/7.10 e 11.7 permanecem pendentes**;
- checkpoint detalhado: `AUDIOVISUAL_11_7_STATUS.md`.

### 11.8 — Triage até zero blocker/critical ✅
O gate estático foi executado contra o ledger canônico e passou sem blocker/critical ativo.
- ledger canônico: `qa/known_issues.json`;
- gate: `tools/qa_triage_gate.py --require-zero`;
- `LOC-116-001`: **resolved**;
- resultado executado: `QA_TRIAGE FINAL: issues=1 active_blocker_critical=0 dependencies=3`;
- resultado final: `QA_TRIAGE PASS: zero blocker/critical product defects`;
- certificação persistida: `QA_11_8_COMPLETION.json`;
- dívidas planejadas de arte, áudio e medição física permanecem dependências de release, não bugs artificiais.

### 11.9 — Soak, sessões longas, suspensão/retomada e confiabilidade 🟡
A infraestrutura fail-closed foi implementada sem duplicar o soak físico de 11.3.
- gate dedicado: `tests/ReliabilitySoakCertification.gd` + `tests/reliability_soak_certification.tscn`;
- contrato: **128 ciclos pause/resume**, cada pause acionando o autosave real; em seguida a RAM é deliberadamente adulterada e o save precisa restaurar sentinel, turno, seed e run ativo;
- **24 restaurações adicionais tipo process restart**, com wipe de `GameState.profile/run`, reload, fingerprint de progressão e auditoria de integridade;
- total esperado antes do roundtrip final: **152 reloads**, com auditoria repetida de `ProfileMigrationEngine` e `RunStateIntegrityEngine`;
- o workflow `Veredas Reliability Soak 11.9` preserva primeiro os gates `MOBILE_CERTIFICATION` 8.2, `SAVE_FUZZ_CERTIFICATION` 11.2 e `RUN_STATE_INTEGRITY_CERTIFICATION` 11.2;
- checkpoint: `RELIABILITY_11_9_STATE.json`;
- primeira tentativa: run `31576124761`, job `94048524964`, terminou com `steps=[]` e `runner_id=0`; portanto não executou o teste;
- 11.9 permanece 🟡 até `RELIABILITY_SOAK_CERTIFICATION PASS: 11.9` executar de verdade no HEAD canônico.

### 11.10 — Freeze de QA / Release Candidate 🟡
A infraestrutura de freeze foi antecipada, mas é deliberadamente impossível promover o RC enquanto faltarem pré-requisitos.
- gate estático fail-closed: `tools/qa_release_candidate_gate.py`;
- workflow: `Veredas QA Freeze 11.10`;
- checkpoint: `QA_11_10_STATE.json`;
- exige `status=pass` e commit certificado ancestral do HEAD para 11.3, 11.6, 11.7, 11.8 e 11.9;
- hoje somente `QA_11_8_COMPLETION.json` satisfaz esse contrato; os comprovantes 11.3/11.6/11.7/11.9 permanecem pendentes;
- o workflow final também reexecuta balance freeze 10.10, zero blocker/critical 11.8, canonical validation, localização completa, regressão 11.1, overflow/iconografia 11.6, audiovisual 11.7 e reliability soak 11.9 no mesmo HEAD;
- exige `git diff --exit-code` ao final, impedindo um RC que altere silenciosamente a árvore durante os testes;
- 11.10 permanece 🟡 até todos os pré-requisitos estarem certificados e o workflow completo passar no HEAD candidato.

### Infraestrutura GitHub Actions — observação atual
As execuções recentes dos gates continuam encerrando antes de qualquer step, com `runner_id=0`. Isso é indisponibilidade de runner e **não** é evidência de PASS nem de falha do código. Gates dependentes de execução permanecem sem certificação até uma execução real.

## Fase 12 — Preflight de publicação já iniciado
### 12.1 — Nome comercial e identidade 🟡
- candidato atual: **Veredas da Trama**;
- reconhecimento público inicial não encontrou colisão exata relevante nas buscas realizadas em web/lojas, mas isso não constitui liberação jurídica;
- estado persistido: `RELEASE_12_1_NAME_STATE.json`;
- faltam busca oficial/interativa no INPI, cross-check WIPO, confirmação autoritativa de domínios/handles e decisão final de estratégia de marca;
- nenhum resultado provisório será tratado como certificação jurídica.

### 12.2 — Package ID, versionamento e assinatura 🟡
- Android application ID estável adotado: **`com.pmartins87.veredasdatrama`**;
- ambos os presets Android e o CI de emulador usam o ID estável;
- estado: `RELEASE_12_2_STATE.json` + `mobile/release_identity.json`;
- validador `tools/validate_android_export.py` exige identidade/versionamento coerentes e ausência de credenciais de release no repositório;
- pipeline `.github/workflows/veredas-release-aab.yml` exige RC certificado, secrets protegidos, AAB assinado, `jarsigner` e SHA-256, destruindo o keystore temporário após o job;
- faltam keystore real/backup externo, secrets protegidos, aceitação do package ID no Play Console, freeze de versão RC e AAB assinado real.

### 12.3 — Privacidade, Data Safety e requisitos de plataforma 🟡
- manifesto técnico: `product/privacy_data_safety.json`;
- política bilíngue fail-closed: `docs/PRIVACY_POLICY_DRAFT.md`, ainda com placeholders explícitos;
- o comportamento atual não inclui ads, analytics, conta própria ou permissões Android customizadas e mantém gameplay/save local;
- Billing de produção ainda não está congelado; 12.4 deverá reabrir a auditoria de fluxo de dados, especialmente para purchase token/validação de titularidade;
- gate `tools/privacy_data_safety_gate.py` possui modo preflight e modo `--release`;
- o AAB assinado está bloqueado por `privacy_data_safety_gate.py --release`, portanto não pode ser produzido enquanto contato, URL, SDKs, retenção e respostas finais de Data Safety estiverem pendentes;
- faltam auditoria pós-12.4, permissões/SDKs do AAB final, URL pública, acesso in-app, contato de privacidade e submissão coerente do formulário Data Safety.

## Fase 10 — Balanceamento — CONCLUÍDA
- 10.1 ✅ simulador completo.
- 10.2 ✅ 36 personagens — 1.296 jornadas.
- 10.3 ✅ 300 monstros + 60 chefes/subchefes — 2.340 combates.
- 10.4 ✅ 1.116 itens, afixos, loot e economia.
- 10.5 ✅ eventos, Marcas, Dívidas, callbacks e 36 arcos.
- 10.6 ✅ quatro dificuldades — 1.728 jornadas pareadas.
- 10.7 ✅ ritmo, recursos e attrition — 1.728 jornadas.
- 10.8 ✅ 17.280 jornadas massivas + 4.608 factíveis em Ruptura.
- 10.9 ✅ 9 playtests adversariais/manual-style.
- 10.10 ✅ freeze automático da superfície balanceável.

## Fase 11 — QA, acessibilidade e localização
- 11.1 ✅ Matriz ampla de regressão automatizada e testes de integração.
- 11.2 ✅ Fuzzing/migração de saves e compatibilidade.
- 11.3 🟡 Performance/memória/bateria/térmica/loading — aparelho físico obrigatório pendente.
- 11.4 ✅ UI responsiva/acessibilidade em matriz de dispositivos.
- 11.5 ✅ Arquitetura de localização; lançamento atual `pt_BR + en`; `es_419` adiado.
- 11.6 🟡 QA linguístico/overflow/iconografia/terminologia — blocker de pack resolvido; execução final dos gates do inglês pendente.
- 11.7 🟡 QA audiovisual em contexto real — preflight implementado; 7.8/7.10 e execução real pendentes.
- 11.8 ✅ Triage até zero blocker/critical — gate `--require-zero` executado com 0 blocker/critical ativo.
- 11.9 🟡 Soak/sessões longas/suspend-resume/confiabilidade — gate e workflow implementados; execução real pendente.
- 11.10 🟡 QA freeze do Release Candidate — gate/workflow implementados; pré-requisitos 11.3/11.6/11.7/11.9 pendentes.

## Fase 12 — Publicação e release
- 12.1 🟡 Validação do nome comercial, disponibilidade e identidade final — preflight em andamento.
- 12.2 🟡 Package ID, versionamento, assinatura e cadeia segura — infraestrutura pronta; credenciais/console/build real pendentes.
- 12.3 🟡 Privacidade, Data Safety, termos e requisitos de plataforma — contrato/gate preparados; congelamento final pós-12.4 pendente.
- 12.4 ⏳ Integração de produção da monetização e restauração de entitlements.
- 12.5 ⏳ Página de loja, screenshots, ícone, feature graphic, vídeo e ASO.
- 12.6 ⏳ AAB/APK final assinado, otimizado e reproduzível.
- 12.7 ⏳ Teste interno/fechado e rollout controlado.
- 12.8 ⏳ Release Candidate final, checklist e rollback.
- 12.9 ⏳ Documentação final, continuidade e suporte.
- 12.10 ⏳ FINAL — pronto para jogar, divulgar e publicar.

## Fase 7 — Assets finais ainda pendentes
- 7.3 🟡 12 Domínios + 120 localidades — grandes ilustrações finais.
- 7.4 🟡 36 personagens + NPCs — ilustrações finais.
- 7.5 🟡 300 monstros + 60 chefes — ilustrações finais.
- 7.8 🟡 áudio/música finais.
- 7.10 ⏳ QA audiovisual final.

## Contagem formal
- **110/130 passos concluídos segundo os gates persistidos.**

## Ponto final
O roadmap termina apenas em **12.10**, com projeto e build completos, testados, empacotados e prontos para jogar, divulgar e publicar.

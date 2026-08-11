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
- Fase 11: **11.1, 11.2, 11.4 e 11.5 ✅; 11.3 aguarda medição física; 11.6, 11.7 e 11.8 em andamento com gates fail-closed**.

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
Commit certificado `37878d1`. Arquitetura de IDs estáveis + overlays de apresentação; fonte/fallback `pt_BR`; idiomas de lançamento `pt_BR`, `en`, `es_419`; conteúdo canônico permanece imutável para regras e balanceamento.

### 11.6 — QA linguístico, overflow, iconografia e terminologia 🟡
A cobertura lógica foi ampliada, mas a etapa **não está certificada no branch canônico**.
- inventário congelado: **5.160 registros / 18.804 unidades de conteúdo localizáveis**;
- UI obrigatória: **119/119** nos três idiomas de lançamento;
- labels mecânicos/lore: **165/165** nos três idiomas;
- glossário canônico e gates de placeholders/BBCode/terminologia/overflow/iconografia existem;
- o compilador reprodutível trabalha com **15.334 unidades de delta por idioma**, complementando **3.470 unidades-base** para o contrato de **18.804/18.804**;
- porém os packs compactos persistidos no HEAD ainda não estão certificados: `en/part_005.b64part` apresenta tamanho anômalo de **59.951 bytes** e `es_419` contém somente `part_000`–`part_002`;
- o defeito foi registrado como **`LOC-116-001` blocker** em `qa/known_issues.json`;
- `localization_pack_certification.py` + `build_launch_localization_packs.py --check` em checkout limpo continuam obrigatórios antes de 11.6 ✅.

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

### 11.8 — Triage até zero blocker/critical 🟡
A infraestrutura de triage foi iniciada sem antecipar PASS.
- ledger canônico: `qa/known_issues.json`;
- gate: `tools/qa_triage_gate.py`;
- workflow: `Veredas QA Triage 11.8`;
- blocker de produto ativo: **`LOC-116-001`**;
- dívidas planejadas de arte, áudio e medição física são registradas separadamente como dependências de release, não como bugs artificiais;
- 11.8 só poderá ser promovida quando o modo `--require-zero` reportar **0 blocker/critical ativos**.

### Infraestrutura GitHub Actions — observação atual
As execuções recentes dos novos gates estão encerrando antes de qualquer step, com `runner_id=0`. Isso é indisponibilidade de runner e **não** é evidência de PASS nem de falha do código. Gates dependentes de Godot permanecem sem certificação até uma execução real.

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
- 11.5 ✅ Arquitetura de localização e idiomas de lançamento.
- 11.6 🟡 QA linguístico/overflow/iconografia/terminologia — cobertura lógica preparada, persistência/certificação final bloqueada por `LOC-116-001`.
- 11.7 🟡 QA audiovisual em contexto real — preflight implementado; 7.8/7.10 e execução real pendentes.
- 11.8 🟡 Triage até zero blocker/critical — ledger/gate implementados; 1 blocker ativo.
- 11.9 ⏳ Soak, sessões longas, suspend/resume e confiabilidade.
- 11.10 ⏳ QA freeze do Release Candidate.

## Fase 7 — Assets finais ainda pendentes
- 7.3 🟡 12 Domínios + 120 localidades — grandes ilustrações finais.
- 7.4 🟡 36 personagens + NPCs — ilustrações finais.
- 7.5 🟡 300 monstros + 60 chefes — ilustrações finais.
- 7.8 🟡 áudio/música finais.
- 7.10 ⏳ QA audiovisual final.

## Contagem formal
- **109/130 passos concluídos segundo os gates persistidos.**

## Ponto final
O roadmap termina apenas em **12.10**, com projeto e build completos, testados, empacotados e prontos para jogar, divulgar e publicar.

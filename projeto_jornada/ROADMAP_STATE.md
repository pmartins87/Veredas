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
- Fase 11: **11.1–11.2 ✅; 11.3 em andamento por depender de medição física; 11.4 iniciado em paralelo**.

## Marcos QA recentes
### 11.1 — Matriz ampla de regressão e integração ✅
Commit limpo `0afd8f2`:
- 288 jornadas completas, 36 personagens × 4 dificuldades × 2 seeds;
- 223 derrotas / 65 vitórias;
- máximo 79 passos, 0 deadlocks, 0 combat timeouts;
- 48 pares determinísticos;
- profile/run/RNG/combat restaurados após simulação;
- 48/48 cenários live com evento, viagem, mercador e combate em todos os 12 Domínios.

### 11.2 — Fuzzing/migração de saves e compatibilidade ✅
Core certificado no commit `39a811c` e re-freeze verificado no commit `7aec534`.
- 192 perfis deformados migráveis: 192 aceitos e normalizados para schema 3;
- 64 estados de jornada deformados: 16 variantes recuperáveis aceitas e 48 semanticamente impossíveis rejeitadas;
- 8/8 arquivos JSON corrompidos recusados;
- rejeições transacionais preservam profile, run, RNG e fingerprint;
- RNG legado ausente é reconstruído deterministicamente;
- estado sentinela legítimo do Hub possui contrato separado de integridade;
- CI, adversarial, regression, save-fuzz e balance-freeze verdes no mesmo re-freeze.

### 11.3 — Performance, memória, bateria, térmica e loading 🟡
A parte automatizada/reproduzível está concluída, mas o gate formal exige aparelho físico conforme `mobile/performance_budgets.json`.

**11.3-A — runtime/headless PASS** (`31349922193`):
- Hub cold load 40,75 ms;
- instanciação do Hub p95 14,95 ms;
- simulação de jornada p95 11,77 ms em 120 ciclos;
- save p95 0,84 ms / load p95 0,88 ms em 24 round-trips;
- pico estático ~68,75 MB; RSS máximo do processo ~159,5 MB;
- deriva pós-aquecimento 0,02 MB;
- zero node drift.

**11.3-B — Android emulator proxy PASS** (`31352049842`, mesmo APK em API 29 e 34):
- API 29 / Android 10: cold 1.715 ms, resume p95 649 ms, pico PSS 200,94 MB, deriva no soak +0,01 MB;
- API 34 / Android 14: cold 1.455 ms, resume p95 1.065 ms, pico PSS 192,50 MB, deriva ~0 MB;
- 12 resumes + 12 amostras de soak em cada API;
- install, pause/autosave, force-stop, relaunch, retomada e persistência continuaram verdes;
- bateria/térmica de emulador são **somente proxy**, não evidência física.

Durante 11.3-B foram encontrados dois problemas de infraestrutura, ambos corrigidos sem alterar gameplay:
1. `swiftshader_indirect` era um backend obsoleto/instável no Android Emulator atual; a CI permanente usa agora `-gpu software`;
2. o coletor tinha colisão de variável POSIX `sh`, que criava loop infinito nos resumes; os contadores foram isolados e o gate passou nas duas APIs.

**11.3-C — aparelho físico pendente:** o protocolo permanente `tools/android_performance_profile.sh` aceita `source=physical` e recusa soak menor que 1.800 s. Sem essa evidência, 11.3 não é marcada concluída.

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
- 11.2 ✅ Fuzzing/migração de saves e compatibilidade com versões anteriores.
- 11.3 🟡 Performance, memória, bateria, térmica e loading — automatização e emuladores verdes; aparelho físico ainda obrigatório.
- 11.4 🟡 UI responsiva/acessibilidade em matriz de dispositivos — iniciado em paralelo enquanto 11.3 aguarda evidência física.
- 11.5 ⏳ Arquitetura de localização e idiomas.
- 11.6 ⏳ QA linguístico, overflow, iconografia e terminologia.
- 11.7 ⏳ QA audiovisual em contexto real.
- 11.8 ⏳ Triage até zero blocker/critical.
- 11.9 ⏳ Soak, sessões longas, suspend/resume e confiabilidade.
- 11.10 ⏳ QA freeze do Release Candidate.

## Fase 7 — Assets finais ainda pendentes
- 7.3 🟡 12 Domínios + 120 localidades — grandes ilustrações finais.
- 7.4 🟡 36 personagens + NPCs — ilustrações finais.
- 7.5 🟡 300 monstros + 60 chefes — ilustrações finais.
- 7.8 🟡 áudio/música finais.
- 7.10 ⏳ QA audiovisual final.

## Contagem formal
- **107/130 passos concluídos segundo seus gates.**

## Ponto final
O roadmap termina apenas em **12.10**, com projeto e build completos, testados, empacotados e prontos para jogar, divulgar e publicar.

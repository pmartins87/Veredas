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
- Fase 11: **11.1, 11.2 e 11.4 ✅; 11.3 aguarda medição física; 11.5 em andamento em paralelo**.

## Marcos QA recentes
### 11.1 — Matriz ampla de regressão e integração ✅
Commit limpo `0afd8f2`:
- 288 jornadas completas, 36 personagens × 4 dificuldades × 2 seeds;
- 223 derrotas / 65 vitórias;
- máximo 79 passos, 0 deadlocks, 0 combat timeouts;
- 48 pares determinísticos;
- profile/run/RNG/combat restaurados após simulação;
- 48/48 cenários live com evento, viagem, mercador e combate nos 12 Domínios.

### 11.2 — Fuzzing/migração de saves e compatibilidade ✅
Core certificado em `39a811c` e re-freeze verificado em `7aec534`:
- 192 perfis deformados migráveis aceitos e normalizados para schema 3;
- 64 estados de jornada: 16 recuperáveis aceitos e 48 impossíveis rejeitados;
- 8/8 arquivos JSON corrompidos recusados;
- rejeição transacional preserva profile/run/RNG/fingerprint;
- RNG legado reconstruído deterministicamente;
- sentinel legítimo do Hub possui contrato separado.

### 11.3 — Performance, memória, bateria, térmica e loading 🟡
A automação está verde; o gate formal ainda exige aparelho físico por 30 minutos.

**11.3-A runtime/headless PASS** (`31349922193`): Hub cold 40,75 ms; instanciação p95 14,95 ms; jornada p95 11,77 ms; save/load p95 0,84/0,88 ms; pico estático ~68,75 MB; RSS ~159,5 MB; deriva 0,02 MB; zero node drift.

**11.3-B Android proxy PASS** (`31352049842`):
- API 29: cold 1.715 ms, resume p95 649 ms, PSS 200,94 MB, deriva +0,01 MB;
- API 34: cold 1.455 ms, resume p95 1.065 ms, PSS 192,50 MB, deriva ~0 MB;
- bateria/térmica de emulador são somente proxy.

**11.3-C físico pendente:** `tools/android_performance_profile.sh source=physical`, soak mínimo 1.800 s.

### 11.4 — UI responsiva e acessibilidade ✅
HEAD limpo `c988448`, workflow `Veredas Responsive Accessibility` run `31421360688`:
- 100 casos de cena;
- 80 modos dinâmicos;
- 1.560 verificações de botões/touch targets;
- 2.320 verificações tipográficas;
- 48 verificações de contraste;
- 5 casos de safe area;
- todos PASS.

O achado real foi a densidade vertical do `Main`; a interface principal foi tornada responsiva e rolável sem reduzir fonte, contraste ou alvo mínimo de toque. No mesmo HEAD também ficaram verdes CI, regression, save-fuzz, adversarial e balance-freeze.

### 11.5 — Arquitetura de localização e idiomas 🟡
Implementação em andamento:
- fonte canônica `pt_BR`;
- idiomas de lançamento: `pt_BR`, `en`, `es_419`;
- conteúdo de regras permanece canônico e imutável;
- apresentação usa overlays por IDs estáveis;
- ausência de tradução cai para pt-BR;
- preferência de idioma vive em `profile.settings.locale`, sem mudança de schema;
- completude de tradução e QA linguístico pertencem ao gate 11.6.

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
- 11.3 🟡 Performance/memória/bateria/térmica/loading — automatização e emuladores verdes; aparelho físico obrigatório pendente.
- 11.4 ✅ UI responsiva/acessibilidade em matriz de dispositivos.
- 11.5 🟡 Arquitetura de localização e idiomas de lançamento.
- 11.6 ⏳ QA linguístico, overflow, iconografia e consistência terminológica.
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
- **108/130 passos concluídos segundo seus gates.**

## Ponto final
O roadmap termina apenas em **12.10**, com projeto e build completos, testados, empacotados e prontos para jogar, divulgar e publicar.

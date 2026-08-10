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
- Fase 11: **11.1–11.2 ✅; 11.3 em andamento**.

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
Core certificado no commit `39a811c` com CI `31349296775`, adversarial `31349296777`, regression `31349296779` e save-fuzz `31349296790` verdes no mesmo HEAD.
- 192 perfis deformados migráveis: 192 aceitos e normalizados para schema 3;
- 64 estados de jornada deformados: 16 variantes explicitamente recuperáveis aceitas e 48 semanticamente impossíveis rejeitadas;
- 8/8 arquivos JSON de save corrompidos recusados;
- rejeições são transacionais: profile, run, RNG e fingerprint vivos permanecem intactos;
- RNG ausente em save legado é reconstruído deterministicamente com `seed` + `state` canônicos;
- estado sentinela legítimo do Hub (`mode=hub`, `active=false`) possui contrato separado de integridade, sem relaxar validação de jornadas ativas;
- round-trip canônico preserva schema 3 e progresso.

A correção da 11.2 alterou `core`, por isso o freeze de balanceamento foi intencionalmente reaberto. Toda a Fase 9, 10.1–10.8, adversarial 10.9 e regressão 11.1 foram reexecutadas antes do novo baseline. `BALANCE_FREEZE.json` agora aponta para `39a811c`; o commit de estado/freeze ainda deve passar sua verificação same-HEAD antes de o re-freeze ser considerado definitivamente fechado.

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
- 11.3 🟡 Performance, memória, bateria, térmica e loading em hardware representativo.
- 11.4 ⏳ UI responsiva/acessibilidade em matriz de dispositivos.
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

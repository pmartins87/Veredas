# Veredas da Trama — Estado Canônico do Roadmap

## Identidade
- Título de trabalho oficial: **Veredas da Trama**.
- O nome comercial definitivo será validado na fase de publicação.
- Regra absoluta: o produto não contém referências ao jogo externo que serviu como inspiração inicial.
- Identidade visual própria: livro-jogo ilustrado à mão, nanquim/grafite, papel orgânico, ornamentação da Trama e paletas dos 12 Domínios.

## Progresso formal
- Fases 0–6: **10/10 ✅ cada**.
- Fase 7: **7.1, 7.2, 7.6, 7.7 e 7.9 ✅**; 7.3–7.5/7.8 em produção; 7.10 pendente.
- Fase 8: **8.1–8.10 ✅ — FASE CONCLUÍDA**.
- Fase 9: **9.1–9.10 ✅ — FASE CONCLUÍDA**.
- Fase 10: **10.1–10.10 ✅ — FASE CONCLUÍDA E BALANCEAMENTO CONGELADO**.
- Fase 11: **11.1 ✅; 11.2 em andamento**.

## Marcos recentes certificados
- commit `1e81f789`: Fase 10 concluída no mesmo HEAD com CI 10.1–10.8, 9/9 playtests adversariais 10.9 e `BALANCE_FREEZE PASS: 10.10`.
- commit `0afd8f2`: **11.1 ✅ Matriz ampla de regressão e integração**. Evidência: 288 jornadas completas em 36 personagens × 4 dificuldades × 2 seeds; 223 derrotas/65 vitórias, máximo 79 passos, zero deadlocks e zero combat timeouts; 48 pares determinísticos; profile/run/RNG/combat restaurados após simulação; 48/48 cenários live com evento, viagem, mercador e combate em todos os 12 Domínios. O primeiro vermelho da 11.1 foi um erro do QA ao interpretar registros de mercador como strings; somente o teste foi corrigido, sem tocar no `core/` congelado.

## Fase 7 — Assets finais ainda pendentes
- 7.1 ✅ Direção de arte.
- 7.2 ✅ Design system.
- 7.3 🟡 12 Domínios + 120 localidades — ilustrações finais.
- 7.4 🟡 36 personagens + NPCs — ilustrações finais.
- 7.5 🟡 300 monstros + 60 chefes — ilustrações finais.
- 7.6 ✅ Iconografia/equipamentos/Marcas.
- 7.7 ✅ VFX artesanais.
- 7.8 🟡 Áudio/música — assets finais.
- 7.9 ✅ Acessibilidade audiovisual.
- 7.10 ⏳ QA audiovisual final.

## Fase 10 — Balanceamento e simulação — CONCLUÍDA
- 10.1 ✅ Simulador completo de jornadas e políticas.
- 10.2 ✅ 36 personagens e curvas de aprendizado — 1.296 jornadas.
- 10.3 ✅ 300 monstros + 60 chefes/subchefes — 2.340 combates.
- 10.4 ✅ 1.116 itens, afixos, loot e economia.
- 10.5 ✅ Eventos, Marcas, Dívidas, callbacks e 36 arcos causais.
- 10.6 ✅ Quatro dificuldades — 1.728 jornadas pareadas.
- 10.7 ✅ Ritmo, duração, recursos e attrition — 1.728 jornadas.
- 10.8 ✅ 17.280 jornadas massivas + 4.608 factíveis em Ruptura; zero deadlocks estruturais; dominância/regret/outliers certificados.
- 10.9 ✅ 9 roteiros adversariais/manual-style.
- 10.10 ✅ Freeze automático da superfície de balanceamento por `BALANCE_FREEZE.json` + `veredas-balance-freeze.yml`.

## Fase 11 — QA, acessibilidade e localização
- 11.1 ✅ Matriz ampla de regressão automatizada e testes de integração — commit limpo `0afd8f2`, workflows regression/freeze/adversarial/CI verdes no mesmo HEAD.
- 11.2 🟡 Fuzzing/migração de saves e compatibilidade com versões anteriores — em andamento. Gate-alvo: 192 perfis deformados, 64 estados de jornada, 8 arquivos corrompidos, transacionalidade, schema 3, idempotência e round-trip canônico.
- 11.3 ⏳ Performance, memória, bateria, térmica e loading.
- 11.4 ⏳ UI responsiva/acessibilidade em matriz de dispositivos.
- 11.5 ⏳ Arquitetura de localização e idiomas.
- 11.6 ⏳ QA linguístico, overflow, iconografia e terminologia.
- 11.7 ⏳ QA audiovisual em contexto real.
- 11.8 ⏳ Triage até zero blocker/critical.
- 11.9 ⏳ Soak, sessões longas, suspend/resume e confiabilidade.
- 11.10 ⏳ QA freeze do Release Candidate.

## Integridade do roadmap
- `ROADMAP_MASTER.md`: roadmap finito 0.1–12.10, total **130 passos**.
- `ROADMAP_RECOVERY.md`: histórico da restauração das fases 8–12.
- `BALANCE_FREEZE.json`: protege regras, geradores e gates balanceáveis; arte, UX, áudio, localização e QA permanecem evolutivos.

## Contagem formal
- **106/130 passos concluídos segundo os gates.**

## Ponto final
O roadmap só termina em **12.10**, com projeto e build completos, testados, empacotados e prontos para jogar, divulgar e publicar.

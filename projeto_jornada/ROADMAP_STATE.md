# Veredas da Trama — Estado Canônico do Roadmap

## Contrato de estado
- Título: **Veredas da Trama**; o produto não referencia o jogo externo usado como inspiração inicial.
- Direção visual: livro-jogo ilustrado à mão, nanquim/grafite, papel orgânico e paletas próprias dos 12 Domínios.
- Roadmap detalhado: `ROADMAP_MASTER.md`.
- `✅` exige PASS/evidência real persistida **e permanece revogável quando evidência humana posterior demonstrar que o critério material não foi atingido**.
- `🟡` é implementação/preflight/evidência pendente ou passo formalmente reaberto; `⏳` é ainda não iniciado.
- Preparar código, contratos, volume de conteúdo, cobertura estrutural ou workflows **não equivale a qualidade de produto e não aumenta a contagem formal por si só**.

## Contagem formal
**107/130 passos concluídos.**

A contagem caiu de 112 para 107 em 2026-08-14 após o primeiro playtest humano em Android físico (`EXP-001`). O teste refutou materialmente cinco certificações anteriores: **6.1, 6.10, 11.4, 11.6 e 11.8**. A correção da contagem é intencional; preservar um número maior seria incompatível com a regra de PASS real.

## Escopo de lançamento
- Idiomas: **pt_BR + en**; `es_419` preservado e adiado.
- Android application ID: **`com.pmartins87.veredasdatrama`**.
- Ponto final: **12.10 — projeto/build completos, testados e prontos para jogar, divulgar e publicar**.

## Stop-ship de experiência — EXP-001
O build Android testado fisicamente em 2026-08-14 é classificado como **harness técnico não representativo**, não como build de jogo candidata a lançamento. O playtest encontrou interface visualmente inerte, ausência dos assets finais, texto procedural sem coesão dramática, escolhas formadas por recombinação de fragmentos, vazamentos de taxonomia/inglês no PT-BR (`Hazard`, `defeat`) e encerramento sem payoff narrativo.

Enquanto `EXP-001` estiver aberto:
- **11.3 fica suspenso**; não há valor em fazer soak de 1.800 s numa experiência que será substancialmente refeita;
- **11.10 e a linha de release ficam bloqueados**;
- Fase 12 pode manter apenas trabalho independente que não desvie esforço da recuperação do produto;
- o próximo marco de produto é uma **vertical slice autoral e audiovisualmente representativa da Mata do Fio Verde**, aprovada em playtest humano antes de escalar novamente.

Plano canônico: `PRODUCT_EXPERIENCE_RECOVERY.md`.

## Fases 0–10
- **0.1–5.10: 10/10 ✅ em cada fase.**
- **Fase 6:** 6.1 🟡 **reaberta** — “conteúdo final” da Mata do Fio Verde/Várzea dos Espelhos foi refutado pelo playtest; 6.2–6.9 ✅ permanecem historicamente certificados, mas deverão ser revisitados se a nova autoria revelar o mesmo padrão sistêmico; 6.10 🟡 **reaberta** — a auditoria de “conteúdo artificial” não detectou a experiência slot-composed que chegou ao jogador.
- **Fase 7:** 7.1 ✅; 7.2 ✅; 7.3 🟡; 7.4 🟡; 7.5 🟡; 7.6 ✅; 7.7 ✅; 7.8 🟡; 7.9 ✅; 7.10 ⏳. Pendências principais: arte final 7.3–7.5 e áudio/música final 7.8 (`DEP-078-AUDIO`). A recuperação de `EXP-001` exige uma amostra representativa desses assets já na vertical slice.
- **8.1–8.10 ✅.**
- **9.1–9.10 ✅.** A funcionalidade do Nó de Vigília permanece implementada, mas sua apresentação visual será retrabalhada dentro da recuperação de experiência.
- **10.1–10.10 ✅ e congelada** em `BALANCE_FREEZE.json`; qualquer mudança mecânica relevante decorrente da reautoria exigirá recertificação antes do RC.

## Fase 11 — QA, otimização e localização
- 11.1 ✅ — regressão/integração ampla; 288 jornadas completas. É evidência funcional histórica, não substituto de playtest qualitativo.
- 11.2 ✅ — fuzzing/migração/corrupção de saves.
- 11.3 🟡 — automação/emuladores verdes, mas **soak físico suspenso por `EXP-001`**. Só será retomado em uma nova candidata representativa depois da vertical slice aprovada.
- 11.4 🟡 **reaberta** — a UI física mostrou problemas de apresentação/legibilidade e uma superfície de acessibilidade visualmente inadequada em contexto real; responsividade geométrica automatizada não bastou.
- 11.5 ✅ — arquitetura de localização; fonte/fallback `pt_BR`, launch `pt_BR + en`.
- 11.6 🟡 **reaberta** — a cobertura estrutural 19.100/19.100 continua sendo evidência histórica válida, mas o playtest revelou vazamento de `Hazard`/`defeat` em PT-BR e demonstrou que o antigo gate não provava coesão semântica/dramática. A nova certificação exigirá QA de texto em contexto e amostragem humana.
- 11.7 🟡 — QA audiovisual real; faltam assets finais, incluindo 38 referências de áudio.
- 11.8 🟡 **reaberta** — `EXP-001` é blocker ativo de produto. A antiga conclusão zero-blocker/critical foi superseded pela evidência humana posterior.
- 11.9 ✅ — reliability soak histórico: 128 ciclos pause/resume, 24 restart rounds, 153 reloads e 155 auditorias de integridade. Deverá ser rerodado após a reautoria substancial antes do RC, mas o PASS histórico continua válido para o código então testado.
- 11.10 🟡 — RC final da Fase 11. Bloqueado por `EXP-001` e exige 11.3/11.6/11.7/11.8/11.9 certificados no produto representativo, além da versão Android pública congelada.

### Infraestrutura de execução
GitHub Actions voltou a executar em runner hospedado após `pmartins87/Veredas` tornar-se público. O fan-out de CI deve permanecer controlado. **Automação agora é tratada como prova de correção mecânica; não como substituto de autoria, direção de arte, coerência narrativa ou diversão.**

## Fase 12 — publicação e release
Toda a Fase 12 permanece formalmente 🟡 e **não é o caminho crítico enquanto `EXP-001` estiver aberto**. Trabalho independente já produzido é preservado, mas nenhuma preparação comercial poderá promover uma build não aprovada como experiência de jogo.

- 12.1 🟡 — **Veredas da Trama** segue candidato; INPI/WIPO/handles/domínios e clearance jurídico final pendentes.
- 12.2 🟡 — package/versionamento/assinatura preparados; chaves/backups/secrets/Play App Signing/fingerprints/versionCode/freeze real pendentes.
- 12.3 🟡 — privacidade/Data Safety/termos/classificação preparados; deploy/TTL/URLs/revisão legal/IARC/Data Safety/Console pendentes.
- 12.4 🟡 — Billing cliente/backend de referência implementado; addon/produtos Play/backend produção/testes reais pendentes.
- 12.5 🟡 — copy e contrato de captura preparados; **screenshots atuais do harness não podem ser usados como material de loja**. Arte final, RC representativo e capturas reais pendentes.
- 12.6 🟡 — cadeia AAB/fingerprint preparada; artefato final assinado e aceito no Play pendente.
- 12.7 🟡 — teste interno/fechado; baseline >=12 testers por >=14 dias contínuos pendente.
- 12.8 🟡 — go/no-go/rollback; bloqueado até experiência e upstream certificados.
- 12.9 🟡 — continuidade/suporte/proveniência/licenças; trabalho de supply chain preservado, evidências finais pendentes.
- 12.10 🟡 — FINAL. PASS somente quando `ready_to_play`, `ready_to_promote`, `ready_to_publish` forem materialmente verdadeiros e decisão `go` estiver sustentada por playtests humanos e gates técnicos.

## Cadeia 11.10 → 12.6
A cadeia de fingerprint/release continua arquiteturalmente válida, porém **nenhum HEAD anterior a `EXP-001` pode ser tratado como RC representativo**. A futura reautoria alterará conteúdo/UI/assets e, portanto, exigirá uma nova certificação 11.10 antes do release.

## Blockers/dependências reais
1. **EXP-001 — stop-ship de experiência:** reconstruir uma vertical slice autoral/visual/sonora da Mata do Fio Verde e obter aprovação humana.
2. Assets finais de arte 7.3–7.5 e áudio 7.8/7.10/11.7; ao menos um conjunto representativo entra na vertical slice antes de escalar.
3. 11.3 — novo soak físico >=1.800 s somente depois de `EXP-001` resolvido e nova APK candidata.
4. 12.2 — upload keystore + backups, secrets, Play App Signing, fingerprints/validades, versionCode e freeze 1.0.0.
5. Play Console, addon Billing, AAB real e backend de produção.
6. Revisão de conteúdo/público-alvo e IARC real.
7. Test track real 12.7.
8. Store: 12 screenshots Android reais apenas de uma build representativa certificada + icon/feature graphic finais.
9. Continuidade final: inventário Android, notices/licenças, direitos dos assets, arquivo, owners/recovery/handoff.
10. Due diligence final do nome e documentação pública/legal.

## Regra de avanço revisada após o playtest físico
- **Qualidade percebida é um gate de produto.** Contagem, volume de JSON, cobertura de localização e testes automatizados não podem substituí-la.
- Nenhum Domínio será escalado a partir da nova abordagem antes de a vertical slice da Mata do Fio Verde passar por playtest humano.
- Textos publicáveis não podem ser gerados apenas pela combinação de slots sem uma espinha narrativa autoral e revisão semântica em contexto.
- O jogador deve encontrar personagens, desejos, conflitos, mistérios, causalidade, consequências, callbacks e desfechos — não categorias de sistema disfarçadas de narrativa.
- Não pedir novo soak físico nem gerar material de loja até existir uma build que represente honestamente o jogo pretendido.
- Nunca aumentar **107/130** por preflight; somente por PASS real persistido e não refutado por evidência posterior.

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
- Fase 11: **11.1, 11.2, 11.4 e 11.5 ✅; 11.3 aguarda medição física; 11.6 em andamento em paralelo**.

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
Commit certificado **`37878d1`**, workflow `31453146197`, com CI/regression/adversarial/save-fuzz/responsive/balance-freeze verdes no mesmo HEAD.
- fonte/fallback canônicos: `pt_BR`;
- idiomas de lançamento: `pt_BR`, `en`, `es_419`;
- 5.160 IDs estáveis inventariados;
- **18.156 strings de conteúdo localizáveis** inventariadas com contexto;
- 14 chaves iniciais de UI × 3 idiomas certificadas;
- aliases de locale e preferência em `profile.settings.locale` certificados;
- overlays não alteram conteúdo canônico nem regras;
- overlays suportam caminhos aninhados, como `choices.0.text`, além de campos de primeiro nível;
- fallback para pt-BR e integridade de placeholders certificados.

### 11.6 — QA linguístico, overflow, iconografia e terminologia 🟡
Em andamento. A tradução integral **não** está sendo considerada pronta.
- glossário canônico iniciado com 20 termos de lore/sistemas/mecânicas;
- exportador contextual das 18.156 unidades em preparação;
- relatório de cobertura por idioma em preparação;
- cobertura de conteúdo alvo ainda é apenas a amostra arquitetural; o gate final 11.6 exigirá tradução completa + QA linguístico/overflow/terminologia.

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
- 11.6 🟡 QA linguístico, overflow, iconografia e consistência terminológica.
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
- **109/130 passos concluídos segundo seus gates.**

## Ponto final
O roadmap termina apenas em **12.10**, com projeto e build completos, testados, empacotados e prontos para jogar, divulgar e publicar.

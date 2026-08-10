# Veredas da Trama — Estado Canônico do Roadmap

## Identidade
- Título de trabalho oficial: **Veredas da Trama**.
- O nome comercial definitivo será validado na fase de publicação.
- Regra absoluta: o produto não contém referências ao jogo externo que serviu como inspiração inicial.
- Identidade visual própria: livro-jogo ilustrado à mão, nanquim/grafite, papel orgânico, ícones integrados, ornamentação da Trama e paletas dos 12 Domínios.

## Progresso formal
- Fases 0–6: **10/10 ✅ cada**.
- Fase 7: **7.1, 7.2, 7.6, 7.7 e 7.9 ✅**; 7.3–7.5/7.8 em produção; 7.10 pendente.
- Fase 8: **8.1–8.10 ✅ — FASE CONCLUÍDA**.
- Fase 9: **9.1–9.10 ✅ — FASE CONCLUÍDA**.
- Fase 10: **10.1–10.9 ✅ certificados; 10.10 está em andamento**.

## Certificação real da engine
A branch canônica possui CI estrita em GitHub Actions com Godot 4.7.1 stable. A CI reconstrói o catálogo, valida conteúdo, importa o projeto sem tolerar erros de parser e executa testes runtime.

Baselines importantes:
- run 31228878267: `RUNTIME_SMOKE PASS` + `PHASE_CERTIFICATION PASS: 1.10 2.10 3.10 4.10`;
- run 31229399274: `MOBILE_CERTIFICATION PASS: 8.1 8.2 8.3 8.4`;
- run 31229966822: `PERFORMANCE_BUDGET_CERTIFICATION PASS: 8.5`, `ASSET_PIPELINE_CERTIFICATION PASS: 8.6` e `ANDROID_EXPORT_CONFIG PASS` para 8.7;
- run 31230627111: APK físico `veredas-debug-apk` exportado e publicado, certificando 8.8;
- run 31231619568: `HUB_CERTIFICATION PASS: 9.1`;
- run 31231957863: `META_UNLOCK_CERTIFICATION PASS: 9.2`;
- run 31232936069: `ECHO_CONSEQUENCE_CERTIFICATION PASS: 9.3` + `JOURNEY_SETUP_CERTIFICATION PASS: 9.4`;
- run 31233210258: `CODEX_PROGRESS_CERTIFICATION PASS: 9.5`;
- run 31234057188: `META_ECONOMY_CERTIFICATION PASS: 9.6`;
- run 31236003837: `COMMERCIAL_POLICY_CERTIFICATION PASS: 9.7` + `ENTITLEMENT_CERTIFICATION PASS: 9.8`;
- run 31236343192: `PROFILE_MIGRATION_CERTIFICATION PASS: 9.9`;
- run 31236557869: `MULTI_JOURNEY_LOOP_CERTIFICATION PASS: 9.10`, junto com todos os gates anteriores da Fase 9;
- run 31237017275: CI completa novamente verde após o marcador determinístico Android, incluindo 9.1–9.10;
- run 31237251316: matriz final Android real — API 29/Android 10 e API 34/Android 14 verdes no mesmo APK, com prontidão do app, seed 881001, schema 3, pause/autosave por recriação física do save, force-stop, relaunch, retomada e segundo autosave certificados;
- run 31299621611: `CHARACTER_BALANCE_CERTIFICATION PASS: 10.2` + `ENEMY_BALANCE_CERTIFICATION PASS: 10.3` no mesmo HEAD, após 1.296 jornadas de balanceamento de personagens e 2.340 combates da matriz inimiga;
- run 31304747936 / commit `0f0ebd1`: `JOURNEY_SIMULATION_CERTIFICATION PASS: 10.1`, `CHARACTER_BALANCE_CERTIFICATION PASS: 10.2`, `ENEMY_BALANCE_CERTIFICATION PASS: 10.3` e `ITEM_ECONOMY_CERTIFICATION PASS: 10.4` no mesmo HEAD. O gate 10.4 certificou os 1.116 itens, 12 tipos funcionais de bônus/afixos, preços e raridades, 7.680 ofertas amostradas de mercador, loot determinístico e taxas observadas de 40,3% para inimigos normais e 90,0% para elites;
- run 31337983973 / commit `4a4e714`: CI canônica limpa com 10.1–10.5 verdes, incluindo `NARRATIVE_BALANCE_CERTIFICATION PASS: 10.5` e regressão integrada 10.1 pós-narrativa. A matriz 10.5 executou 216 jornadas / 12.960 seleções, cobertura narrativa de 92,7%, 693 origens de Dívida, 352 callbacks exatos, 569 consequências de trânsito, participação de arco de 2,7%, 85 estágios distintos alcançados e progressão até estágio 4;
- run 31339193258 / commit `c5b40d5`: CI canônica limpa com `DIFFICULTY_BALANCE_CERTIFICATION PASS: 10.6`. A matriz 10.6 executou 1.728 jornadas pareadas e certificou a curva monotônica Contemplativa → Andarilho → Severa → Ruptura, com zero deadlocks estruturais;
- run 31340262854 / commit `00dde061`: CI canônica limpa com 10.1–10.7 verdes e `JOURNEY_PACING_CERTIFICATION PASS: 10.7`. A matriz executou 1.728 jornadas; Provisões passaram a gerar attrition real `Provisão → Vigor → Vida`; `world.varzea_espelhos` permaneceu como maior duração média e foi levado explicitamente à etapa 10.8;
- run 31344471146 / commit `31baec22`: CI canônica limpa com 10.1–10.8 todos verdes e `MASS_SIMULATION_CERTIFICATION PASS: 10.8`. A matriz principal executou 17.280 jornadas com 0 inválidas, 0 deadlocks, 0,27% de stalemates e 2,21% acima de 35 passos. Políticas permaneceram plurais (`balanced` 130, `aggressive` 102, `cautious` 191, `explorer` 90, 63 empates) e builds também (`offense` 415, `defense` 167, `utility` 81, 57 empates). O stress factível em Ruptura executou mais 4.608 jornadas, com 1,26% de vitória agregada, 0,04% de stalemates e máximo local de 21,9%;
- runs **31345097609** (`Veredas da Trama CI`) e **31345097632** (`Veredas Adversarial Playtests`) / commit **`e922d928`**: certificação same-HEAD da Fase 10 até 10.9. A CI longa passou 10.1–10.8; o workflow adversarial permanente passou 9/9 roteiros manual-style: empilhamento/spam de Guarda, ação inválida, movement lock, Dívida/callback, attrition de viagem, arbitragem de mercador, escolha/cooldown de evento, determinismo manual e isolamento dos builds sintéticos.

## Catálogo canônico
- 5.160 registros; 12 mundos; 120 localidades; 96 famílias; 300 monstros; 60 chefes/subchefes; 1.116 itens; 300 NPCs; 204 Marcas; 120 Dívidas; 36 personagens; 72 habilidades; 2.544 eventos; 36 finais; 144 pools.
- 88,719% de estruturas narrativas normalizadas únicas; 968 assinaturas de escolhas; 0 erros estruturais no QA certificado.
- Pirâmide econômica dos itens certificada: 480 comuns, 288 incomuns, 168 raros, 96 singulares, 60 relíquias e 24 Ecos.

## Fase 7
- 7.1 ✅ Direção de arte.
- 7.2 ✅ Design system.
- 7.3 🟡 12 Domínios + 120 localidades — grandes ilustrações finais pendentes.
- 7.4 🟡 36 personagens + NPCs — ilustrações finais pendentes.
- 7.5 🟡 300 monstros + 60 chefes — ilustrações finais pendentes.
- 7.6 ✅ Iconografia/equipamentos/Marcas.
- 7.7 ✅ VFX artesanais integrados.
- 7.8 🟡 Áudio/música — arquitetura pronta, assets finais pendentes.
- 7.9 ✅ Acessibilidade audiovisual.
- 7.10 ⏳ QA audiovisual final e limpeza de leaks headless.

## Fase 8 — Mobile/Android — CONCLUÍDA
- 8.1 ✅ Safe areas e layout responsivo.
- 8.2 ✅ Pause/resume, autosave e recuperação.
- 8.3 ✅ Touch e Android Back.
- 8.4 ✅ Layout tall/standard/wide e leitura responsiva.
- 8.5 ✅ Orçamentos e instrumentação de performance mobile.
- 8.6 ✅ Pipeline mobile de assets, budgets e cache LRU.
- 8.7 ✅ Presets Android: debug APK + Play AAB arm64, validação de segurança e nenhum segredo de release no Git.
- 8.8 ✅ Build Android automatizada — APK físico exportado e publicado como artefato da CI.
- 8.9 ✅ Compatibilidade real no mesmo APK em API 29/Android 10 e API 34/Android 14, com emuladores headless, KVM e diagnósticos permanentes.
- 8.10 ✅ Install/launch/pause-autosave/force-stop/relaunch: prontidão real do app, seed 881001 + schema 3, recriação do save no pause, relaunch da jornada persistida e segundo autosave coerente.

## Fase 9 — Metaprogressão — CONCLUÍDA
- 9.1 ✅ Nó de Vigília funcional como hub persistente.
- 9.2 ✅ Desbloqueios de personagens, rotas, modos e Códice, sem aumento de poder-base.
- 9.3 ✅ Marcas de Eco, finais e consequências persistentes entre jornadas; condições narrativas consultam a memória sem bônus automáticos de Vida/dano.
- 9.4 ✅ Preparação da jornada — rota, Andarilho, modo, quatro perfis de dificuldade, seed e modificadores; setup persistente e normalizado.
- 9.5 ✅ Arquivo de Ecos/Códice — coleção por categoria, conquistas, histórico, migração do Códice legado e save/load; repetição não duplica histórico.
- 9.6 ✅ Economia meta horizontal — Fios de Vigília por marcos únicos; ledger idempotente; gastos apenas em conveniência/expressão, nunca poder.
- 9.7 ✅ Modelo comercial formal — demo do primeiro Domínio, desbloqueio único do jogo completo e pacote opcional puramente cosmético; sem anúncios, assinatura, loot box, consumível pago, venda de Fios ou pay-to-win.
- 9.8 ✅ Entitlements, restauração e offline — licença não consumível, cache local, restauração autoritativa e revogação segura; entitlement não concede atributos.
- 9.9 ✅ Migrações/regressão/integridade — schema de perfil 3, migração idempotente, reparo conservador, fingerprint de metaprogressão, save/load e rejeição segura de schema futuro.
- 9.10 ✅ Loop completo entre múltiplas jornadas — três jornadas, dois Domínios, entitlement sem bypass, Ecos/consequências, recompensas idempotentes, finais coerentes com o Domínio, save/load entre ciclos, crescimento do Nó e Vida/Vigor-base invariáveis.

## Fase 10 — Balanceamento e simulação
- 10.1 ✅ Simulador completo de jornadas e políticas de jogador.
- 10.2 ✅ Balanceamento dos 36 personagens e suas curvas de aprendizado — certificado com 1.296 jornadas controladas.
- 10.3 ✅ Balanceamento dos 300 monstros, elites e 60 chefes/subchefes — certificado com 2.340 combates, fases funcionais e timeouts dentro do gate.
- 10.4 ✅ Balanceamento dos 1.116 itens, afixos, loot e economia de jornada — raridades, preços, mercadores, drops, upgrades e efeitos de equipamento integrados e certificados.
- 10.5 ✅ Frequências de eventos, Marcas, Dívidas, callbacks e arcos narrativos — 216 jornadas / 12.960 escolhas, cobertura 92,7%, loops de Dívida finitos e 36 arcos causais certificados.
- 10.6 ✅ Calibração dos quatro modos de dificuldade — 1.728 jornadas pareadas, quatro curvas distintas e monotônicas, Andarilho preservado como baseline, zero deadlocks estruturais.
- 10.7 ✅ Ritmo de progressão, duração, recursos e attrition das jornadas — 1.728 jornadas; Provisões funcionais, fallback para Vigor/Vida, cadência/cauda/fluxo econômico certificados.
- 10.8 ✅ Simulações massivas, detecção de outliers e estratégias dominantes — 17.280 jornadas massivas + 4.608 jornadas factíveis em Ruptura, zero deadlocks estruturais, dominância/regret/outliers certificados.
- 10.9 ✅ Playtests adversariais/manuais e correção dos resultados da simulação — 9 roteiros manual-style certificados em workflow permanente no mesmo HEAD da CI 10.1–10.8.
- 10.10 🟡 Freeze de balanceamento com gates estatísticos aprovados — em implementação; o manifesto de freeze protegerá regras, geradores e gates sem congelar arte/texto/UX.

## Integridade do roadmap
- `ROADMAP_MASTER.md`: roadmap 0.1–12.10.
- `ROADMAP_RECOVERY.md`: registro transparente da restauração da redação perdida das fases 8–12.

## Contagem formal
- **104/130 passos concluídos segundo seus gates.**

## Ponto final
O roadmap só termina em 12.10 com projeto e build completos, testados, empacotados e prontos para jogar, divulgar e publicar.

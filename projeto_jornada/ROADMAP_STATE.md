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
- Fase 10: **10.1 é o próximo passo**.

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
- run 31237251316: matriz final Android real — API 29/Android 10 e API 34/Android 14 verdes no mesmo APK, com prontidão do app, seed 881001, schema 3, pause/autosave por recriação física do save, force-stop, relaunch, retomada e segundo autosave certificados.

## Catálogo canônico
- 5.160 registros; 12 mundos; 120 localidades; 96 famílias; 300 monstros; 60 chefes/subchefes; 1.116 itens; 300 NPCs; 204 Marcas; 120 Dívidas; 36 personagens; 72 habilidades; 2.544 eventos; 36 finais; 144 pools.
- 88,719% de estruturas narrativas normalizadas únicas; 968 assinaturas de escolhas; 0 erros estruturais no QA certificado.

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
- 8.10 ✅ Install/launch/pause-autosave/force-stop/relaunch: o gate espera prontidão real do app, valida seed 881001 + schema 3, remove o save em disco e exige recriação no pause; depois relança a jornada persistida, espera `resumed`, remove novamente o save e exige um segundo autosave com o mesmo personagem, Domínio e seed.

## Fase 9 — Metaprogressão — CONCLUÍDA
- 9.1 ✅ Nó de Vigília funcional — hub persistente horizontal, instalações, residentes, rotas e crescimento por marcos.
- 9.2 ✅ Desbloqueios horizontais de personagens, rotas, modos e Códice, sem aumento de poder-base.
- 9.3 ✅ Marcas de Eco, finais e consequências persistentes entre jornadas; condições narrativas consultam a memória sem bônus automáticos de Vida/dano.
- 9.4 ✅ Preparação da jornada — rota, Andarilho, modo, quatro perfis de dificuldade, seed e modificadores; setup persistente e normalizado.
- 9.5 ✅ Arquivo de Ecos/Códice — coleção por categoria, conquistas, histórico, migração do Códice legado e save/load; repetição não duplica histórico.
- 9.6 ✅ Economia meta horizontal — Fios de Vigília por marcos únicos; ledger idempotente; gastos apenas em conveniência/expressão, nunca poder.
- 9.7 ✅ Modelo comercial formal — demo do primeiro Domínio, desbloqueio único do jogo completo e pacote opcional puramente cosmético; sem anúncios, assinatura, loot box, consumível pago, venda de Fios ou pay-to-win.
- 9.8 ✅ Entitlements, restauração e offline — licença não consumível, cache local, restauração autoritativa e revogação segura; entitlement não concede atributos.
- 9.9 ✅ Migrações/regressão/integridade — schema de perfil 3, migração idempotente, reparo conservador, fingerprint de metaprogressão, save/load e rejeição segura de schema futuro.
- 9.10 ✅ Loop completo entre múltiplas jornadas — três jornadas, dois Domínios, entitlement sem bypass, Ecos/consequências, recompensas idempotentes, finais coerentes com o Domínio, save/load entre ciclos, crescimento do Nó e Vida/Vigor-base invariáveis.

## Fase 10 — Balanceamento e simulação
- 10.1 ⏭ Simulador completo de jornadas e políticas de jogador.
- 10.2–10.10 ⏳ Pendentes após certificação de 10.1.

## Integridade do roadmap
- `ROADMAP_MASTER.md`: roadmap 0.1–12.10.
- `ROADMAP_RECOVERY.md`: registro transparente da restauração da redação perdida das fases 8–12.

## Contagem formal
- **95/130 passos concluídos segundo seus gates.**

## Ponto final
O roadmap só termina em 12.10 com projeto e build completos, testados, empacotados e prontos para jogar, divulgar e publicar.

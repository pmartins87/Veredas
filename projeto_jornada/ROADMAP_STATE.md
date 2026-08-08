# Veredas da Trama — Estado Canônico do Roadmap

## Identidade
- Título de trabalho oficial: **Veredas da Trama**.
- O nome comercial definitivo será validado na fase de publicação.
- Regra absoluta: o produto não contém referências ao jogo externo que serviu como inspiração inicial.
- Identidade visual própria: livro-jogo ilustrado à mão, nanquim/grafite, papel orgânico, ícones integrados, ornamentação da Trama e paletas dos 12 Domínios.

## Progresso formal
- Fases 0–6: **10/10 ✅ cada**.
- Fase 7: **7.1, 7.2, 7.6, 7.7 e 7.9 ✅**; 7.3–7.5/7.8 em produção; 7.10 pendente.
- Fase 8: **8.1–8.8 ✅**; 8.9–8.10 aguardam certificação nos emuladores Android 10/14.

## Certificação real da engine
A branch canônica possui CI estrita em GitHub Actions com Godot 4.7.1 stable. A CI reconstrói o catálogo, valida conteúdo, importa o projeto sem tolerar erros de parser e executa testes runtime.

Baselines importantes:
- run 31228878267: `RUNTIME_SMOKE PASS` + `PHASE_CERTIFICATION PASS: 1.10 2.10 3.10 4.10`;
- run 31229399274: `MOBILE_CERTIFICATION PASS: 8.1 8.2 8.3 8.4`;
- run 31229966822: `PERFORMANCE_BUDGET_CERTIFICATION PASS: 8.5`, `ASSET_PIPELINE_CERTIFICATION PASS: 8.6` e `ANDROID_EXPORT_CONFIG PASS` para 8.7;
- run 31230627111: `Export debug APK` e upload do artefato `veredas-debug-apk` concluídos; artefato GitHub Actions id 9013679272, digest `sha256:4d08b2bebf577a1601058b99b543c8705bad22b438b1f5d286c2be3cea6e12e3`.

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

## Fase 8 — Mobile/Android
- 8.1 ✅ Safe areas e layout responsivo.
- 8.2 ✅ Pause/resume, autosave e recuperação.
- 8.3 ✅ Touch e Android Back.
- 8.4 ✅ Layout tall/standard/wide e leitura responsiva.
- 8.5 ✅ Orçamentos e instrumentação de performance mobile.
- 8.6 ✅ Pipeline mobile de assets, budgets e cache LRU.
- 8.7 ✅ Presets Android: debug APK + Play AAB arm64, validação de segurança e nenhum segredo de release no Git. Package ID atual é provisório.
- 8.8 ✅ Build Android automatizada — APK físico exportado e publicado como artefato da CI.
- 8.9 🔄 Matriz Android 10/14 configurada para consumir exatamente o APK certificado; aguarda encerramento do job de build para executar.
- 8.10 ⏳ Certificação install/launch/pause-save/force-stop/relaunch aguarda os dois emuladores.

## Integridade do roadmap
- `ROADMAP_MASTER.md`: roadmap 0.1–12.10.
- `ROADMAP_RECOVERY.md`: registro transparente da restauração da redação perdida das fases 8–12.

## Contagem formal
- **83/130 passos concluídos/materializados segundo seus gates.**

## Ponto final
O roadmap só termina em 12.10 com projeto e build completos, testados, empacotados e prontos para jogar, divulgar e publicar.

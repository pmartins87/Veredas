# Veredas da Trama — Estado Canônico do Roadmap

## Identidade
- Título de trabalho oficial: **Veredas da Trama**.
- O nome comercial definitivo será validado na fase de publicação (busca de disponibilidade, marca, lojas e ASO).
- Regra absoluta: o produto não deve conter nomes, logotipos, textos, personagens, interface, assets, metadata ou menções ao jogo externo que serviu como referência inicial.
- A identidade visual é original: livro-jogo ilustrado à mão, linhas de nanquim/grafite, papel/textura orgânica, ícones integrados ao texto, ornamentação da Trama e paletas próprias dos 12 Domínios.

## Progresso formal
- Fase 0 — Fundação: **10/10 ✅**.
- Fase 1 — Arquitetura: **10/10 ✅**; 1.10 certificado na Godot real.
- Fase 2 — Protótipo funcional: **10/10 ✅**; 2.10 certificado por jornada runtime ponta a ponta.
- Fase 3 — Motor industrial de conteúdo: **10/10 ✅**; 3.10 certificado em runtime.
- Fase 4 — Combate profundo: **10/10 ✅**; 4.10 certificado em runtime.
- Fase 5 — Mundo e narrativa: **10/10 ✅**.
- Fase 6 — Produção massiva: **10/10 ✅**; fonte canônica e QA determinísticos persistidos.
- Fase 7 — Arte, UX e áudio: 7.1, 7.2, 7.6, 7.7 e 7.9 concluídos; 7.3–7.5 e 7.8 em produção; 7.10 pendente.
- Fase 8 — Plataforma mobile e Android: **8.1–8.4 ✅ certificados na Godot real**; 8.5–8.10 em produção/pendentes.

## Certificação real da engine
A branch canônica possui CI estrita em GitHub Actions usando **Godot 4.7.1 stable** headless.

A CI executa reconstrução determinística, QA canônico, QA audiovisual, importação da engine sem tolerar erros de parser, RuntimeSmoke e certificações específicas por fase.

Baselines certificados:
- run **31228878267**: `RUNTIME_SMOKE PASS` e `PHASE_CERTIFICATION PASS: 1.10 2.10 3.10 4.10`;
- run **31229399274**: todos os gates anteriores + `MOBILE_CERTIFICATION PASS: 8.1 8.2 8.3 8.4`.

Observação de QA: execuções headless ainda podem reportar objetos/recursos em uso no encerramento dos testes. Isso não alterou resultados funcionais e permanece como dívida explícita para 7.10/11.x; não está resolvido.

## Fonte canônica reconstruível
- `ROADMAP_MASTER.md`: roadmap finito 0.1–12.10 persistido.
- `ROADMAP_RECOVERY.md`: registro transparente da restauração da redação perdida de 8–12.
- `project.godot` e motores centrais estão persistidos na branch.
- `tools/rebuild_content.py` recria deterministicamente todo o catálogo de dados.
- `tools/refine_npc_authenticity.py` garante diversidade contextual das pressões privadas dos NPCs.
- `tools/validate_canonical.py` audita quotas, referências e autenticidade.
- `REBUILD_AND_VERIFY.md` documenta a sequência única de reconstrução.
- `tests/runtime_smoke.tscn` testa conteúdo, RNG, eventos, combate, save, tema, acessibilidade e assets vetoriais.
- `tests/phase_certification.tscn` certifica explicitamente os gates 1.10–4.10.
- `tests/mobile_certification.tscn` certifica 8.1–8.4.

Baseline atual do catálogo canônico:
- 12 mundos
- 120 localidades
- 96 famílias
- 300 monstros
- 60 chefes/subchefes
- 1.116 itens
- 300 NPCs
- 204 Marcas
- 120 Dívidas Narrativas
- 36 personagens
- 72 habilidades
- 2.544 eventos
- 36 finais
- 144 pools
- **5.160 registros totais**
- **88,719%** de estruturas narrativas normalizadas únicas
- **968** assinaturas de escolhas no reconstrutor canônico atual
- **0 erros estruturais** no QA canônico certificado

## Fase 7
- 7.1 ✅ Direção de arte definitiva.
- 7.2 ✅ Design system completo da interface.
- 7.3 🟡 Arte dos 12 Domínios e 120 localidades — paletas, 12 ornamentos finais, contratos e manifest materializados; 132 grandes ilustrações finais pendentes.
- 7.4 🟡 Arte dos 36 personagens e NPCs — 108 contratos principais de personagem e estratégia modular de NPCs materializados; ilustrações finais pendentes.
- 7.5 🟡 Arte dos 300 monstros e 60 chefes — 96 famílias-mãe + 60 contratos de chefes materializados; ilustrações finais pendentes.
- 7.6 ✅ Ícones, equipamentos e Marcas — 32 ícones sistêmicos finais, 48 glifos-base de Marca, 24 arquétipos de item, 12 ornamentos de Domínio e composição visual determinística; 1.116 itens com arquétipo visual válido.
- 7.7 ✅ Animações e VFX — página, escolha, dano, Marca, Intenção, fase de chefe e viagem integrados via PresentationBus/PresentationVFXController com redução de movimento e bloqueio de flashes.
- 7.8 🟡 Áudio e música — identidade sonora dos 12 Domínios, manifest e roteador implementados; arquivos sonoros/musicais finais pendentes.
- 7.9 ✅ Acessibilidade audiovisual — escala de fonte, alto contraste, redução de movimento, flashes, rótulos, haptics e detalhe de combate persistentes e testados.
- 7.10 ⏳ Integração e QA audiovisual final — depende das grandes artes e áudio final; inclui limpeza de leaks headless.

## Fase 8 — Mobile/Android
- 8.1 ✅ Safe areas e layout responsivo — `DisplayServer.get_display_safe_area()`, SafeAreaMargin, leitura vertical e `canvas_items + expand`, certificado.
- 8.2 ✅ Ciclo de vida mobile — autosave em pause/Back/close, recuperação do save no boot e resume, certificado.
- 8.3 ✅ Touch/Back — alvos mínimos de 48 px, `quit_on_go_back=false`, navegação contextual e Back certificado.
- 8.4 ✅ Densidades/tamanhos — classes tall/standard/wide e limite de medida de leitura em telas largas, certificado.
- 8.5 ⏭ Orçamento e instrumentação de performance mobile.
- 8.6 ⏳ Pipeline de assets mobile.
- 8.7 ⏳ Preset/exportação Android.
- 8.8 ⏳ Build Android automatizada em CI.
- 8.9 ⏳ Matriz de emuladores/dispositivos/versões Android.
- 8.10 ⏳ Certificação de build Android instalável, jogável e retomável.

## Contagem formal
- Passos materializados/concluídos no sentido estrito do roadmap: **79/130**.

## Ponto final
O roadmap só termina em 12.10 com build final completa, testada, empacotada e pronta para jogar, divulgar e publicar.

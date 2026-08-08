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

## Certificação real da engine
A partir de 2026-08-07, a branch canônica possui CI estrita em GitHub Actions usando **Godot 4.7.1 stable** headless.

A CI executa, nesta ordem:
1. reconstrução determinística do conteúdo;
2. refinamento autoral determinístico dos NPCs;
3. QA canônico de conteúdo;
4. QA de integração audiovisual;
5. importação do projeto pela Godot com falha obrigatória em `SCRIPT ERROR`, `Parse Error` ou script não carregado;
6. `RuntimeSmoke`;
7. `PhaseCertification` para 1.10–4.10.

Baseline certificado no run **31228878267**:
- importação Godot sem erros de parser;
- `RUNTIME_SMOKE PASS`;
- `PHASE_CERTIFICATION PASS: 1.10 2.10 3.10 4.10`;
- QA canônico e QA da Fase 7 em PASS.

Observação de QA: a execução headless ainda reporta objetos/um recurso em uso no encerramento do processo de teste. Isso não alterou resultados nem estado funcional e fica registrado como dívida de limpeza para 7.10/QA final; não é considerado resolvido.

## Fonte canônica reconstruível
- `project.godot` e motores centrais estão persistidos na branch.
- `tools/rebuild_content.py` recria deterministicamente todo o catálogo de dados.
- `tools/refine_npc_authenticity.py` garante diversidade contextual das pressões privadas dos NPCs.
- `tools/validate_canonical.py` audita quotas, referências e autenticidade.
- `REBUILD_AND_VERIFY.md` documenta a sequência única de reconstrução.
- `tests/runtime_smoke.tscn` testa conteúdo, RNG, eventos, combate, save, tema, acessibilidade e assets vetoriais.
- `tests/phase_certification.tscn` certifica explicitamente os gates 1.10–4.10.

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
- 7.6 ✅ Ícones, equipamentos e Marcas — 32 ícones sistêmicos finais, 48 glifos-base de Marca, 24 arquétipos de item, 12 ornamentos de Domínio e composição visual determinística. Os 1.116 itens possuem arquétipo visual válido no catálogo canônico.
- 7.7 ✅ Animações e VFX — vocabulário completo de papel/tinta integrado: assentamento de página, feedback de escolha, manchas de dano, costura de Marca, revelação de Intenção, ruptura de fase e transição de localidade; PresentationBus + PresentationVFXController desacoplam gameplay e UI; redução de movimento e bloqueio de flashes respeitados.
- 7.8 🟡 Áudio e música — identidade sonora dos 12 Domínios, manifest e DomainAudioRouter implementados; arquivos sonoros/musicais finais pendentes.
- 7.9 ✅ Acessibilidade audiovisual — painel in-game e serviço persistente para escala de fonte, alto contraste, redução de movimento, flashes, rótulos, haptics e detalhe de combate; integrado à UI e exercitado no RuntimeSmoke da Godot.
- 7.10 ⏳ Integração e QA audiovisual final — depende das grandes artes e do áudio final; inclui limpeza dos leaks do encerramento headless.

## Pipeline/integração visual persistidos
- `ui/domain_palettes.json`: paletas canônicas dos 12 Domínios.
- `ui/assets/vector/system_icons_atlas.svg`: 32 ícones desenhados em linha orgânica.
- `ui/assets/vector/mark_glyphs_atlas.svg`: 48 glifos-base de Marcas.
- `ui/assets/vector/item_archetypes_atlas.svg`: 24 arquétipos de itens/equipamentos.
- `ui/assets/vector/domain_ornaments_atlas.svg`: 12 motivos próprios de Domínio.
- `ui/VectorAtlasRegistry.gd`: recorte determinístico dos atlases.
- `ui/ItemVisualComposer.gd`: composição de visual por item, raridade, Domínio e afixos.
- `ui/InlineIconRegistry.gd`: ícones reais do atlas dentro de RichText.
- `ui/BookCardStyle.gd`: gramática original de cartões/página costurada.
- `ui/BookVFX.gd`: linguagem de movimento artesanal.
- `ui/PresentationBus.gd` + `ui/PresentationVFXController.gd`: ligação desacoplada entre gameplay e VFX.
- `ui/shaders/parchment_paper.gdshader`: fibras, envelhecimento e lavagem cromática procedural.
- `ui/DomainThemeService.gd`: aplica paletas por Domínio no runtime e alto contraste.
- `ui/AccessibilityProfile.gd`, `ui/AccessibilityService.gd` e `ui/AccessibilityPanel.gd`: acessibilidade persistente e configurável durante a jornada.
- `audio/domain_audio_manifest.json` e `audio/DomainAudioRouter.gd`: roteamento de UI, combate, música e ambiência por Domínio.
- `scenes/Main.gd`: interface multimodo de jornada, inventário, comércio, viagem, combate, finais e debrief no mesmo idioma visual de livro-jogo.

## Contagem formal
- Passos materializados/concluídos no sentido estrito do roadmap: **75/130**.

## Ponto final
O roadmap só termina em 12.10 com build final completa, testada, empacotada e pronta para jogar, divulgar e publicar.

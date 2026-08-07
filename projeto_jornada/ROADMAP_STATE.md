# Veredas da Trama — Estado Canônico do Roadmap

## Identidade
- Título de trabalho oficial: **Veredas da Trama**.
- O nome comercial definitivo será validado na fase de publicação (busca de disponibilidade, marca, lojas e ASO).
- Regra absoluta: o produto não deve conter nomes, logotipos, textos, personagens, interface, assets, metadata ou menções ao jogo externo que serviu como referência inicial.
- A identidade visual é original: livro-jogo ilustrado à mão, linhas de nanquim/grafite, papel/textura orgânica, ícones integrados ao texto, ornamentação da Trama e paletas próprias dos 12 Domínios.

## Progresso formal
- Fase 0 — Fundação: 10/10 materializada.
- Fase 1 — Arquitetura: 9/10 materializada; 1.10 aguarda certificação na Godot real.
- Fase 2 — Protótipo funcional: 9/10 materializada; 2.10 aguarda certificação na Godot real.
- Fase 3 — Motor industrial de conteúdo: 9/10 materializada; 3.10 aguarda certificação na Godot real.
- Fase 4 — Combate profundo: 9/10 materializada; 4.10 aguarda certificação na Godot real.
- Fase 5 — Mundo e narrativa: 10/10 materializada.
- Fase 6 — Produção massiva: 10/10 materializada; fonte canônica e QA determinísticos persistidos.
- Fase 7 — Arte, UX e áudio: 7.1, 7.2 e 7.6 concluídos; 7.3–7.5 e 7.7–7.9 em produção; 7.10 pendente.

## Fonte canônica reconstruível
- `project.godot` e motores centrais estão persistidos na branch.
- `tools/rebuild_content.py` recria deterministicamente todo o catálogo de dados.
- `tools/validate_canonical.py` audita quotas, referências e autenticidade.
- `REBUILD_AND_VERIFY.md` documenta a sequência única de reconstrução.
- `tests/runtime_smoke.tscn` + `tests/RuntimeSmoke.gd` aguardam execução numa Godot real.

Baseline do catálogo canônico verificado no ambiente de produção em 2026-08-07:
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
- **1.028** assinaturas de escolhas
- **0 erros estruturais** no QA canônico local correspondente

## Fase 7
- 7.1 ✅ Direção de arte definitiva.
- 7.2 ✅ Design system completo da interface.
- 7.3 🟡 Arte dos 12 Domínios e 120 localidades — paletas, 12 ornamentos finais, contratos e manifest materializados; 132 grandes ilustrações finais pendentes.
- 7.4 🟡 Arte dos 36 personagens e NPCs — 108 contratos principais de personagem e estratégia modular de NPCs materializados; ilustrações finais pendentes.
- 7.5 🟡 Arte dos 300 monstros e 60 chefes — 96 famílias-mãe + 60 contratos de chefes materializados; ilustrações finais pendentes.
- 7.6 ✅ Ícones, equipamentos e Marcas — 32 ícones sistêmicos finais, 48 glifos-base de Marca, 24 arquétipos de item, 12 ornamentos de Domínio e composição visual determinística. Os 1.116 itens possuem arquétipo visual válido no catálogo canônico.
- 7.7 🟡 Animações e VFX — primitivas de movimento de tinta/papel e shader de pergaminho implementados; integração e efeitos finais pendentes.
- 7.8 🟡 Áudio e música — identidade sonora dos 12 Domínios, manifest e DomainAudioRouter implementados; arquivos sonoros/musicais finais pendentes.
- 7.9 🟡 Acessibilidade audiovisual — perfil runtime para escala de fonte, alto contraste, redução de movimento, flashes, rótulos e haptics implementado; integração e testes finais pendentes.
- 7.10 ⏳ Integração e QA audiovisual.

## Pipeline/integração visual já persistidos
- `ui/domain_palettes.json`: paletas canônicas dos 12 Domínios.
- `ui/assets/vector/system_icons_atlas.svg`: 32 ícones desenhados em linha orgânica.
- `ui/assets/vector/mark_glyphs_atlas.svg`: 48 glifos-base de Marcas.
- `ui/assets/vector/item_archetypes_atlas.svg`: 24 arquétipos de itens/equipamentos.
- `ui/assets/vector/domain_ornaments_atlas.svg`: 12 motivos próprios de Domínio.
- `ui/VectorAtlasRegistry.gd`: recorte determinístico dos atlases.
- `ui/ItemVisualComposer.gd`: composição de visual por item, raridade, Domínio e afixos.
- `ui/InlineIconRegistry.gd`: ícones reais do atlas dentro de RichText.
- `ui/BookCardStyle.gd`: gramática original de cartões/página costurada.
- `ui/shaders/parchment_paper.gdshader`: fibras, envelhecimento e lavagem cromática procedural.
- `ui/DomainThemeService.gd`: aplica paletas por Domínio no runtime.
- `ui/InkMotion.gd`: transições discretas de livro/tinta com suporte a movimento reduzido.
- `ui/AccessibilityProfile.gd`: preferências audiovisuais acessíveis persistíveis.
- `audio/domain_audio_manifest.json` e `audio/DomainAudioRouter.gd`: roteamento de UI, combate, música e ambiência por Domínio.
- `scenes/Main.gd`: já aplica pergaminho, tema do Domínio, ornamento, cartões e estatísticas com ícones do atlas.

## Contagem formal
- Passos materializados/concluídos no sentido estrito do roadmap: **69/130**.

## Ponto final
O roadmap só termina em 12.10 com build final completa, testada, empacotada e pronta para jogar, divulgar e publicar.

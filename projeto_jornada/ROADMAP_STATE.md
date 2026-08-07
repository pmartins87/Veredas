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
- Fase 6 — Produção massiva: 10/10 materializada e autenticidade revalidada.
- Fase 7 — Arte, UX e áudio: 7.1 e 7.2 concluídos; 7.3–7.9 possuem infraestrutura/especificação materializada, mas aguardam assets finais e integração para conclusão; 7.10 pendente.

## Fase 7
- 7.1 ✅ Direção de arte definitiva.
- 7.2 ✅ Design system completo da interface.
- 7.3 🟡 Arte dos 12 Domínios e 120 localidades — contratos, paletas e manifest builder materializados; 132 ilustrações finais pendentes.
- 7.4 🟡 Arte dos 36 personagens e NPCs — 108 contratos principais de personagem e estratégia modular de NPCs materializados; ilustrações finais pendentes.
- 7.5 🟡 Arte dos 300 monstros e 60 chefes — 96 famílias-mãe + 60 contratos de chefes materializados; ilustrações finais pendentes.
- 7.6 🟡 Ícones, equipamentos e Marcas — geradores originais de 32 ícones sistêmicos e 48 glifos-base de Marca materializados; cobertura final de equipamentos/ícones pendente.
- 7.7 🟡 Animações e VFX — primitivas de movimento de tinta/papel implementadas; integração e efeitos finais pendentes.
- 7.8 🟡 Áudio e música — manifest de eventos, identidade sonora dos 12 Domínios e AudioRouter implementados; arquivos sonoros/musicais finais pendentes.
- 7.9 🟡 Acessibilidade audiovisual — perfil runtime para escala de fonte, alto contraste, redução de movimento, flashes, rótulos e haptics implementado; UI e testes finais pendentes.
- 7.10 ⏳ Integração e QA audiovisual.

## Pipeline da Fase 7
- `ui/domain_palettes.json`: paletas canônicas dos 12 Domínios.
- `tools/build_phase7_manifest.py`: gera 476 contratos visuais principais.
- `tools/generate_system_icons.py`: gera 32 ícones sistêmicos originais em SVG.
- `tools/generate_mark_glyphs.py`: gera 48 glifos-base originais de Marcas.
- `tools/validate_phase7_assets.py`: gate rígido; deve falhar enquanto houver asset final faltando.
- `tools/prepare_phase7.py`: executa geração determinística + QA em um comando.
- `ui/DomainThemeService.gd`: aplica paletas por Domínio no runtime.
- `ui/InlineIconRegistry.gd`: converte tokens semânticos em ícones inline no texto.
- `ui/InkMotion.gd`: transições discretas de livro/tinta com suporte a movimento reduzido.
- `ui/AccessibilityProfile.gd`: preferências audiovisuais acessíveis persistíveis.
- `audio/audio_events.json` e `audio/AudioRouter.gd`: roteamento de UI, combate, música e ambiência por Domínio.

## Contagem formal
- Passos materializados/concluídos no sentido estrito do roadmap: **68/130**.
- O número não foi aumentado nesta rodada porque 7.3–7.9 ainda não satisfazem seus gates de conteúdo final e integração.

## Ponto final
O roadmap só termina em 12.10 com build final completa, testada, empacotada e pronta para jogar, divulgar e publicar.

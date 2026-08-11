# Veredas da Trama — Checkpoint 11.7

## Estado

**11.7 — QA audiovisual final em contexto real: 🟡 preflight implementado; certificação final bloqueada.**

Este arquivo é deliberadamente fail-closed: a existência da infraestrutura abaixo **não autoriza** promover 11.7 para concluída enquanto os assets finais de áudio da 7.8 e o QA audiovisual 7.10 não estiverem completos e o gate final não tiver executado com sucesso.

## Contrato audiovisual de lançamento

O manifesto `audio/audio_events.json` define:

- 5 buses: `Master`, `Music`, `Ambience`, `SFX`, `UI`;
- 7 eventos de UI;
- 7 eventos de combate;
- 12 Domínios;
- 2 camadas persistentes por Domínio (`music` + `ambience`);
- total de **38 referências de áudio**;
- pelo menos 3 motivos de assinatura por Domínio.

No estado deste checkpoint, os caminhos finais `res://assets/audio/**` ainda não estão presentes no repositório. Isso é dívida de produção da **7.8**, não deve ser mascarado por placeholders silenciosos.

## Integração implementada nesta passagem

`AudioRouter` agora é autoload e:

- garante os cinco buses em runtime;
- conecta os sinais reais de `PresentationBus`;
- roteia página, escolha, Marca, dano, intenção e fase de chefe;
- resolve `location.* -> world.<domínio> -> <domínio>` e troca música/ambiência do Domínio;
- expõe sinais de auditoria para provar qual evento/domínio foi roteado e se o asset resolveu;
- mantém gameplay e feedback visual/textual funcionais mesmo quando áudio está ausente;
- expõe auditoria fail-closed do manifesto e dos recursos.

## Política de mix

`audio/audio_mix.json` codifica o princípio **sound_supports_reading**:

- Master: 0 dB;
- Music: -15 dB;
- Ambience: -18 dB;
- SFX: -9 dB;
- UI: -8 dB;
- música limitada a no máximo -12 dB;
- ambiência limitada a no máximo -15 dB;
- margem mínima de 4 dB entre camada de fundo e foreground;
- informação essencial não pode depender de áudio;
- feedback visual/textual paralelo é obrigatório.

Esses níveis são baseline de roteamento, não substituem medição perceptual dos masters finais.

## Gates permanentes

- `tools/validate_phase7_integration.py` — valida autoload, hooks, manifesto e assinaturas.
- `tools/audit_audio_assets.py` — valida contrato de 38 referências, paths, arquivos, assinaturas e mix; `--require-final` torna qualquer asset ausente fatal.
- `tests/AudiovisualContextCertification.gd` — exercita os sinais de apresentação e os 12 Domínios em Godot.
- `tests/audiovisual_context_certification.tscn` — cena do gate.
- `.github/workflows/veredas-audiovisual-context.yml` — preflight permanente.

O teste Godot só imprime `AUDIOVISUAL_CONTEXT_CERTIFICATION PASS: 11.7` quando os 38 assets finais resolvem. Sem eles, pode apenas imprimir `AUDIOVISUAL_CONTEXT_PREFLIGHT PASS` e o bloqueio explícito.

## Bloqueadores para 11.7 ✅

1. **7.8** — produzir/integrar os 14 SFX de UI/combate e 24 camadas musicais/ambiência dos 12 Domínios em qualidade final.
2. **7.10** — QA audiovisual final, inclusive mix perceptual, referências quebradas e identidade dos Domínios.
3. Executar o gate Godot final com todos os 38 assets presentes.
4. Regressões no mesmo HEAD devem permanecer verdes.

## Infraestrutura externa

As execuções mais recentes de GitHub Actions encerraram antes de qualquer step, com `runner_id=0`. Isso não é evidência de falha do código nem PASS. Nenhuma promoção de roadmap deve usar esses runs enquanto não houver execução real.

## Contagem

Este checkpoint **não aumenta a contagem formal do roadmap**. Até nova certificação canônica, manter a contagem registrada no `ROADMAP_STATE.md` e tratar 11.7 como pendente.

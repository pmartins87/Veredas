# Veredas da Trama — Checkpoint 11.6

Status: **EM ANDAMENTO**. Este arquivo não promove 11.6 para concluída.

## Último estado certificado por CI — histórico
- Run: `31458154371`, commit `e8ab835` — PASS no escopo vigente naquele commit.
- Fonte canônica/fallback: `pt_BR`.
- Naquele momento, os alvos ainda incluíam `en` e `es_419`.
- Registros estáveis: 5.160.
- Unidades de conteúdo: 18.804.
- UI: 119/119 por idioma então avaliado.
- Labels: 165/165 por idioma então avaliado.
- Conteúdo naquele checkpoint: 3.074/18.804 por alvo (16,35%).
- Restante histórico: 15.730 unidades por alvo, organizado em 40 lotes determinísticos de até 400 unidades.
- SHA-256 histórico das chaves-fonte: `19e1807176210a8191cda20db4b89002380f2ff150f9603a2c9a3c28db59ce63`.

Esse PASS histórico **não define o escopo de lançamento atual** e não certifica o corpus completo atual.

## Escopo de lançamento atual
- Fonte/fallback: **pt_BR**.
- Idiomas de lançamento: **pt_BR + en**.
- `es_419` permanece preservado como idioma **adiado** para expansão futura e não integra os gates do release atual.
- O manifesto `localization/manifest.json` é a autoridade para seleção de idiomas de lançamento.
- A redução de escopo não relaxa nenhum requisito de qualidade do inglês: o alvo continua sendo **18.804/18.804** unidades, UI/labels completos, integridade de placeholders/BBCode/glossário, sanity linguístico, overflow e iconografia/acessibilidade.

## Cobertura inglesa atual persistida
- Base inglesa do último baseline verde: **3.074** unidades.
- Nomes adicionais de famílias/monstros: **396** unidades.
- Delta compacto inglês: **15.334** unidades.
- Equação de cobertura: **3.074 + 396 + 15.334 = 18.804**.
- UI: **119/119** em `pt_BR` e `en`.
- Labels: **165/165** em `pt_BR` e `en`.
- Pack físico inglês: `part_000` a `part_009`, contíguos, total Base64 **133.572 caracteres**.

## Gates atuais
- `tools/build_launch_localization_packs.py` — deriva alvos do manifesto e preserva catálogos adiados.
- `tools/localization_pack_certification.py` — certifica apenas alvos atuais e exige cobertura inglesa completa, sem colisões/chaves desconhecidas e com paridade de tokens/BBCode.
- `tools/localization_quality_gate.py` — incorpora o pack compacto antes de verificar completude, glossário, placeholders e BBCode.
- `tools/localization_full_linguistic_sanity.py` — deriva alvos do manifesto.
- `tests/LocalizationOverflowCertification.gd` — `pt_BR + en`.
- `tests/LocalizationIconographyCertification.gd` — `pt_BR + en`.
- `tests/LocalizationArchitectureCertification.gd` — exige exatamente `pt_BR + en` como launch locales e verifica que `es_419` continua preservado, porém não selecionável.

## Blocker resolvido
`LOC-116-001` está **resolvido** no contrato atual: o pack inglês físico está íntegro e o espanhol adiado não pode permanecer acidentalmente como blocker do release.

## Observação de CI
Os workflows recentes continuam terminando antes de executar qualquer step (`runner_id=0`, `steps=[]`). Isso é tratado como ausência de executor, não como falha ou PASS funcional. Nenhum resultado novo é promovido a certificado até uma execução real no HEAD correspondente.

## Gate para concluir 11.6
11.6 só poderá virar ✅ quando, no mesmo HEAD de lançamento:
1. o inglês for certificado em **18.804/18.804** unidades e o pack compacto em **15.334** unidades, com zero colisões/chaves desconhecidas/erros de tokens;
2. o QA completo de glossário/placeholders/BBCode passar com o pack incorporado;
3. o sanity linguístico final do inglês passar;
4. overflow/renderização passarem em `pt_BR` e `en` na matriz responsiva;
5. iconografia e rótulos de acessibilidade passarem em `pt_BR` e `en`;
6. a arquitetura confirmar `pt_BR + en` e rejeitar `es_419` como idioma de lançamento;
7. as regressões relevantes passarem no mesmo HEAD limpo.

Somente então **11.6 ✅** poderá ser registrado.

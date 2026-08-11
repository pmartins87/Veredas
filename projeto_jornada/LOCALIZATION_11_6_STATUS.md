# Veredas da Trama — Checkpoint 11.6

Status: **EM ANDAMENTO**. Este arquivo não promove 11.6 para concluída.

## Último estado certificado por CI
- Run: `31458154371`, commit `e8ab835` — PASS.
- Fonte canônica/fallback: `pt_BR`.
- Alvos de lançamento: `en`, `es_419`.
- Registros estáveis: 5.160.
- Unidades de conteúdo: 18.804.
- UI: 119/119 por idioma.
- Labels: 165/165 por idioma.
- Conteúdo: 3.074/18.804 por idioma (16,35%).
- Restante: 15.730 unidades por idioma, organizado em 40 lotes determinísticos de até 400 unidades.
- Restante contém 9.840 strings-fonte únicas e 5.890 ocorrências repetidas elegíveis a memória de tradução.
- SHA-256 das chaves-fonte: `19e1807176210a8191cda20db4b89002380f2ff150f9603a2c9a3c28db59ce63`.

## Trabalho persistido após o último PASS
- `461c492`: +96 nomes de famílias e +300 nomes de monstros traduzidos por idioma.
- `63085be`: proteção permanente dessas traduções no pipeline.
- `ddd840c`: `tools/localization_quality_gate.py`, cobrindo paridade de placeholders printf/braces, BBCode, terminologia do glossário, traduções idênticas suspeitas e riscos de expansão de UI.
- `65e6600`: workflow independente `Veredas Localization Quality 11.6`.
- `b8d9a1c`: endurecimento do workflow de qualidade com permissão read-only explícita.

## Observação de CI
A primeira tentativa do workflow novo terminou sem executar nenhum step, com `runner_id=0`. O mesmo ocorreu com Balance Freeze no mesmo HEAD. Isso é tratado como ausência de execução do runner, não como falha funcional do jogo ou do gate. Nenhum número pós-`e8ab835` é promovido a certificado até uma execução real.

## Gate para concluir 11.6
11.6 só poderá virar ✅ quando `en` e `es_419` atingirem 100% de conteúdo, labels e UI; placeholders/markup e glossário estiverem íntegros; overflow/renderização forem validados nos idiomas de lançamento; iconografia/legendas estiverem coerentes; e as regressões relevantes estiverem verdes no mesmo HEAD.

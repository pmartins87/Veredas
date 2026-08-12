# Veredas da Trama — Continuidade, Release e Suporte

Este documento é o runbook operacional do passo **12.9**. Ele não contém segredos, chaves privadas, senhas ou material de assinatura. Os valores pessoais/operacionais que ainda dependem de configuração real permanecem no contrato `product/continuity_support_contract.json` como placeholders fail-closed.

## 1. Fontes de verdade

- Repositório: `pmartins87/desktop-tutorial`.
- Branch de desenvolvimento canônico: `projeto-jornada-snapshots`.
- Estado formal: `ROADMAP_STATE.md`.
- Roadmap finito: `ROADMAP_MASTER.md`.
- Estado de QA: arquivos `QA_*`, `RELIABILITY_*` e `qa/known_issues.json`.
- Estado de publicação: arquivos `RELEASE_12_*_STATE.json` e contratos em `product/` e `mobile/`.
- Um release público somente pode ser identificado por commit imutável + tag final + versionName/versionCode + SHA-256 do AAB + fingerprint de assinatura.

## 2. Regra de reconstrução

Uma pessoa que receba acesso autorizado ao projeto deve conseguir reconstruir o produto sem depender de arquivos de trabalho não documentados. O procedimento mínimo é:

1. obter o commit/tag certificado;
2. conferir `REBUILD_AND_VERIFY.md` e `export_presets.cfg`;
3. executar os gates canônicos e o freeze do RC;
4. usar apenas secrets protegidos do ambiente de release para assinatura/serviços externos;
5. gerar o fingerprint de inputs de release;
6. produzir o AAB no commit exato;
7. validar package ID, versão e assinatura;
8. registrar SHA-256 do artefato e comparar com a evidência do RC/test track.

Nenhum keystore, senha, token da Play Console, segredo de backend ou credencial de API deve ser adicionado ao Git.

## 3. Cadeia de assinatura e recuperação

A identidade de assinatura é um ativo crítico. A release final exige:

- backup externo do keystore/material autorizado de assinatura;
- confirmação de que esse backup pode ser restaurado;
- registro apenas do fingerprint público do certificado no arquivo de continuidade;
- recuperação da conta Play Console verificada;
- recuperação do repositório verificada;
- recuperação do backend de Billing verificada quando este entrar em produção.

Uma troca de máquina não pode ser tratada como troca de identidade de assinatura.

## 4. Saves, perfil e compatibilidade

- Saves publicados são contratos de compatibilidade.
- Atualizações devem manter leitura dos saves públicos ou fornecer migração explícita e testada.
- Não se publica hotfix que exija downgrade de `versionCode`.
- Rollback de software é feito por nova versão corretiva, não por exigir que usuários voltem para um APK/AAB de versão inferior.
- Migrações continuam fail-closed para estados impossíveis/corrompidos.
- Antes de qualquer alteração de schema pós-release, os testes de migração, integridade e suspend/resume devem ser reexecutados.

## 5. Billing e entitlements

- `PENDING` nunca concede entitlement.
- Compra somente concede após verificação autoritativa conforme o contrato de Billing.
- Restore deve preservar o último cache validado diante de falha parcial.
- Hotfixes e mudanças de backend não podem invalidar compras previamente verificadas.
- Reembolso/revogação devem continuar sendo tratados de acordo com o fluxo certificado no test track.

## 6. Privacidade e Data Safety

Qualquer novo SDK, permissão, telemetria, conta, serviço de nuvem, publicidade ou fluxo de dados exige nova auditoria de 12.3 antes da publicação. A declaração da Play Store e a política pública devem descrever o comportamento do AAB realmente publicado, não um estado anterior do projeto.

Logs de suporte devem coletar apenas o necessário para reproduzir o problema. Não solicitar segredos, credenciais ou dados pessoais desnecessários.

## 7. Localização

O lançamento atual é `pt_BR + en`. `es_419` permanece preservado como trabalho adiado e não deve aparecer como idioma de lançamento até obter uma certificação futura própria de cobertura, qualidade linguística, overflow e iconografia.

## 8. Assets e licenças

Antes do release final devem estar arquivados:

- proveniência dos assets finais;
- licenças e atribuições de terceiros aplicáveis;
- versão final da política de privacidade;
- textos finais da loja;
- release notes;
- hashes/fingerprints do artefato e inputs de release.

O arquivo de continuidade não substitui a prova de licença/proveniência.

## 9. Suporte e triage

O canal público de suporte deve direcionar cada caso para evidência suficiente: versão/versionCode, dispositivo/Android quando relevante, passos de reprodução, comportamento esperado/observado e classificação de impacto em save, Billing ou privacidade.

Prioridade operacional:

- **blocker**: perda de dados, impossibilidade ampla de abrir/jogar, falha sistêmica de entitlement ou incidente material de privacidade/segurança;
- **critical**: funcionalidade central indisponível para parcela relevante dos usuários sem workaround seguro;
- **major/minor/trivial**: severidades decrescentes conforme impacto e disponibilidade de workaround.

O ledger de QA continua sendo a fonte de verdade para defeitos de produto. Dependências planejadas não devem ser mascaradas como bugs, e bugs release-blocking não devem ser mascarados como dependências.

## 10. Incidente e rollback/hotfix

A primeira publicação pública não deve pressupor que existe uma versão pública anterior para a qual retornar. O plano é manter um hotfix de maior `versionCode`, mesma identidade de assinatura e compatibilidade com saves/entitlements pronto para ser produzido rapidamente.

Para atualizações subsequentes, usar rollout progressivo quando suportado e interromper a expansão ao detectar blocker/critical, corrupção de save, regressão material de Billing, crash/ANR ou privacidade/política. A correção continua sendo uma nova versão crescente; nunca um downgrade imposto ao usuário.

## 11. Passagem de bastão

Uma transferência operacional só é considerada completa quando outra pessoa autorizada consegue localizar as fontes de verdade, verificar a identidade do último release, restaurar os acessos externos previstos, reproduzir a cadeia de build sem receber segredos pelo repositório e entender os procedimentos de save, Billing, privacidade, suporte e hotfix.

A identidade das pessoas/canais responsáveis é deliberadamente mantida fora deste documento até ser configurada no contrato final de 12.9.

## 12. Gate final de 12.9

O passo 12.9 somente pode ser promovido quando `tools/continuity_support_gate.py --release` passar. O preflight estrutural não é evidência de conclusão do release.

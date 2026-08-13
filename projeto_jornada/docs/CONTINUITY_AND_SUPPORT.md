# Veredas da Trama — Continuidade, Release e Suporte

Este documento é o runbook operacional do passo **12.9**. Ele não contém segredos, chaves privadas, senhas ou material de assinatura. Os valores pessoais/operacionais que ainda dependem de configuração real permanecem no contrato `product/continuity_support_contract.json` como placeholders fail-closed.

## 1. Fontes de verdade

- Repositório: `pmartins87/desktop-tutorial`.
- Branch de desenvolvimento canônico: `projeto-jornada-snapshots`.
- Estado formal: `ROADMAP_STATE.md`.
- Roadmap finito: `ROADMAP_MASTER.md`.
- Estado de QA: arquivos `QA_*`, `RELIABILITY_*` e `qa/known_issues.json`.
- Estado de publicação: arquivos `RELEASE_12_*_STATE.json` e contratos em `product/` e `mobile/`.
- Proveniência/licenças/dependências: `product/release_provenance.json` + `tools/provenance_license_gate.py`.
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
8. registrar SHA-256 do artefato e comparar com a evidência do RC/test track;
9. reconciliar o artefato com os inventários finais de dependências, licenças e proveniência.

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

## 8. Proveniência de assets e direitos

`product/release_provenance.json` é a fonte de verdade para qualquer arquivo visual, de áudio ou fonte versionado que possa entrar no produto. O gate acompanha extensões de mídia/fontes e exige correspondência arquivo a arquivo.

Classes de origem aceitáveis incluem trabalho original do projeto, encomenda com direitos de release documentados, terceiro licenciado, domínio público verificado ou derivação gerada a partir de fonte própria devidamente registrada. A classe não substitui a evidência: autoria/fonte, base de direitos e, quando aplicável, licença/cessão devem ser arquivadas.

São **proibidos no release**:

- screenshots, imagens, áudio ou outros assets extraídos dos jogos usados apenas como referência conceitual;
- material encontrado na web sem licença de redistribuição verificável;
- assets de autoria ou licença desconhecida;
- material de terceiro cuja obrigação de atribuição/licença não tenha sido preservada no arquivo de release.

Neste estágio estrutural ainda não há arte/áudio/fontes finais binários versionados; isso não é uma dispensa. É justamente o motivo para a catraca existir antes da entrada dos assets finais.

Quando um asset final for adicionado, a mesma mudança deve adicionar/atualizar sua linha de proveniência. `tools/provenance_license_gate.py` deve falhar se a árvore e o manifesto divergirem.

## 9. Software de terceiros, lock e SBOM

Pin de dependência direta não é suficiente para reconstrução ou conformidade de licenças. O release final exige:

- Godot e plugin Android identificados por versão/fonte;
- dependências diretas do backend reconciliadas com `requirements.txt`;
- **dependências transitivas do backend totalmente travadas por versão e hashes** em `backend/play_purchase_verifier/requirements.lock`;
- SBOM da imagem final do backend arquivado em `product/software_sbom.json`;
- relatório final de dependências Gradle/Android reconciliado e arquivado em `product/android_dependency_inventory.json`;
- licença/notice aplicável de cada componente redistribuído ou runtime revisado e arquivado;
- qualquer obrigação de atribuição preservada no produto/arquivo de release quando necessária.

A ausência de lock transitivo é tratada como risco real: um `requirements.txt` com apenas dependências diretas pinadas ainda pode resolver versões transitivas diferentes em datas diferentes.

Serviços hospedados (Google Play, Android Developer API, Cloud Run e Firestore no desenho atual) não são fingidos como “bibliotecas com LICENSE”. Seus termos/políticas aplicáveis, papel no fluxo de dados e configuração de produção precisam de revisão separada e arquivada.

## 10. Arquivo jurídico e público

Além dos manifests técnicos, o arquivo final deve conter:

- proveniência dos assets finais e evidências de direitos;
- licenças/notices de terceiros aplicáveis;
- versão final da política de privacidade e termos;
- textos finais da loja;
- release notes;
- hashes/fingerprints do artefato e inputs de release;
- SBOM/backend lock e inventário Android final;
- registro de revisão dos serviços externos de produção.

O arquivo de continuidade não substitui a prova de licença/proveniência.

## 11. Suporte e triage

O canal público de suporte deve direcionar cada caso para evidência suficiente: versão/versionCode, dispositivo/Android quando relevante, passos de reprodução, comportamento esperado/observado e classificação de impacto em save, Billing ou privacidade.

Prioridade operacional:

- **blocker**: perda de dados, impossibilidade ampla de abrir/jogar, falha sistêmica de entitlement ou incidente material de privacidade/segurança;
- **critical**: funcionalidade central indisponível para parcela relevante dos usuários sem workaround seguro;
- **major/minor/trivial**: severidades decrescentes conforme impacto e disponibilidade de workaround.

O ledger de QA continua sendo a fonte de verdade para defeitos de produto. Dependências planejadas não devem ser mascaradas como bugs, e bugs release-blocking não devem ser mascarados como dependências.

## 12. Incidente e rollback/hotfix

A primeira publicação pública não deve pressupor que existe uma versão pública anterior para a qual retornar. O plano é manter um hotfix de maior `versionCode`, mesma identidade de assinatura e compatibilidade com saves/entitlements pronto para ser produzido rapidamente.

Para atualizações subsequentes, usar rollout progressivo quando suportado e interromper a expansão ao detectar blocker/critical, corrupção de save, regressão material de Billing, crash/ANR ou privacidade/política. A correção continua sendo uma nova versão crescente; nunca um downgrade imposto ao usuário.

## 13. Passagem de bastão

Uma transferência operacional só é considerada completa quando outra pessoa autorizada consegue localizar as fontes de verdade, verificar a identidade do último release, restaurar os acessos externos previstos, reproduzir a cadeia de build sem receber segredos pelo repositório e entender os procedimentos de save, Billing, privacidade, suporte, proveniência/licenças e hotfix.

A identidade das pessoas/canais responsáveis é deliberadamente mantida fora deste documento até ser configurada no contrato final de 12.9.

## 14. Gates finais de 12.9

O passo 12.9 somente pode ser promovido quando, no mesmo release ancestry:

1. `tools/provenance_license_gate.py --release` passar;
2. `tools/continuity_support_gate.py --release` passar;
3. a evidência externa exigida pelo contrato estiver realmente arquivada.

O preflight estrutural não é evidência de conclusão do release.

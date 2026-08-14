# Veredas da Trama — Continuidade, Release e Suporte

Este é o runbook operacional do passo **12.9**. Ele não contém segredos e não equivale a evidência de conclusão. O release só é certificado quando os artefatos reais, hashes, owners, recuperação e gates correspondentes existem na mesma ancestry.

## 1. Fontes de verdade
- Repositório: `pmartins87/desktop-tutorial`.
- Branch de desenvolvimento: `projeto-jornada-snapshots`.
- Estado formal: `ROADMAP_STATE.md` e `PROJECT_STATE.json`.
- Contrato 12.9: `product/continuity_support_contract.json`.
- Proveniência: `product/release_provenance.json`.
- Notices: `product/third_party_notices.json`.
- Recovery/backup drill: `product/recovery_backup_drill.json`.
- Arquivo final: `product/release_archive_manifest.json`.

Um release público é identificado por **tag + commit + versionName/versionCode + SHA-256 do AAB + fingerprint de assinatura + fingerprint dos inputs**.

## 2. Fingerprint e reprodutibilidade
`tools/release_input_fingerprint.py` cobre inputs reais de build/runtime. `tools/release_input_scope_gate.py` impede que evidências de release entrem no próprio fingerprint e verifica referências runtime `res://product/...`.

Os recursos `product/` atualmente consumidos pelo jogo são `commercial_model.json` e `legal_documents.json`. Manifestos de evidência ficam fora do fingerprint para evitar auto-referência.

O workflow assinado gera o manifesto de inputs antes do export e exige equivalência depois do import/export.

## 3. Arquivo canônico — 12 itens
`product/release_archive_manifest.json` exige **12 itens obrigatórios**, todos hashados:

1. manifesto de inputs do release;
2. proveniência dos assets/software;
3. lock de dependências do backend;
4. SBOM do backend;
5. manifesto de notices/licenças de terceiros;
6. inventário de dependências Android;
7. Política de Privacidade final;
8. Termos finais;
9. store listing final;
10. release notes;
11. registro público da identidade de assinatura;
12. registro de recovery/backup drill (`product/recovery_backup_drill.json`).

O AAB não precisa ser cometido ao Git; sua identidade/hash e evidência externa permanecem referenciados sem material secreto.

## 4. Proveniência de assets
Cada imagem/vetor/áudio/fonte versionado para release deve ter caminho, blob Git atual, origem, base de direitos, evidência e elegibilidade explícita.

Os quatro SVGs atuais já estão ligados ao blob atual e ao commit de introdução. A revisão final de direitos permanece pendente; histórico Git não substitui clearance jurídico.

São proibidos assets extraídos dos jogos usados como referência, material web sem licença verificável e qualquer arquivo de origem/direitos desconhecidos.

## 5. Dependências Python: lock e SBOM
Pin direto não basta. O release exige todo o conjunto transitivo travado por versão + SHA-256.

A cadeia é:
- `tools/build_backend_dependency_evidence.py`;
- `tools/backend_dependency_evidence_gate.py`;
- `.github/workflows/veredas-backend-dependency-evidence.yml`.

A resolução ocorre em **Python 3.12/Linux**. O venv congelado recebe apenas dependências runtime reais; ferramentas de evidência não são instaladas nele.

O gerador lê `Name`, `Version`, licença e `Requires-Dist` diretamente do `.dist-info/METADATA` de cada wheel usando apenas `zipfile`/`email` da biblioteca padrão. O SBOM registra hash do `requirements.txt`, versão do pip, ambiente, pacote direto/transitivo, PURL, wheel e SHA-256.

A prova final precisa:
1. resolver o ambiente;
2. `pip check`;
3. congelar o conjunto;
4. baixar exatamente um wheel por distribuição;
5. gerar `requirements.lock` com hashes;
6. gerar SBOM;
7. validar contra requisitos/proveniência;
8. reinstalar **offline** em venv limpo com `--require-hashes`;
9. executar `pip check` novamente;
10. provar freeze reconstruído idêntico;
11. compilar/importar o backend.

Não criar lock/SBOM manualmente para preencher evidência.

## 6. Dependências Android do AAB exato
`tools/gradle_dependency_inventory.init.gradle` resolve `releaseRuntimeClasspath` no mesmo projeto Gradle que produz o AAB. O inventário guarda coordenadas Maven ou identidade local fail-closed, arquivo AAR/JAR, tamanho, SHA-256 e ambiente.

`tools/android_dependency_inventory_gate.py` exige que todas as entradas `com.android.billingclient` usem exatamente a versão congelada em 12.4 e que todo artefato runtime possua identidade/hash verificável.

O resultado final é arquivado em `product/android_dependency_inventory.json`.

## 7. Notices/licenças
SBOM/inventário respondem **o que entrou**; `third_party_notices.json` responde **qual licença/obrigação acompanha cada componente**.

`tools/third_party_notices_gate.py` exige cobertura dos componentes conhecidos, de todo SBOM backend e de toda dependência Android third-party, com review final e arquivos LICENSE/NOTICE/copyright/attribution hashados quando aplicável.

Licença identificada em fonte primária não equivale a revisão final.

## 8. Billing e retenção
O backend persiste apenas SHA-256 do token + estado mínimo. A política de retenção é finita:
- PURCHASED/owned real: 730 dias desde a última atividade;
- bound/PENDING/CANCELLED/non-owned: 30 dias;
- compra de teste: 7 dias.

`expires_at` é o campo TTL. Atividade legítima renova a janela sem regredir estado monotônico. Expiração nunca é prova de entitlement; um registro ausente/expirado só pode ser recriado após nova verificação autoritativa no Google Play.

Produção ainda precisa habilitar e verificar TTL no Firestore antes do release.

## 9. Assinatura, segredos e recuperação
Nunca versionar keystore privada, senha, chave JSON de service account, token, recovery code ou qualquer credencial.

A evidência canônica é `product/recovery_backup_drill.json`, validada por `tools/recovery_backup_drill_gate.py`. Ela registra apenas status, fingerprints públicos e referências não secretas.

O drill final exige seis cenários:
1. recuperar acesso ao repositório;
2. recuperar acesso ao Play Console;
3. recuperar o backend de Billing, sua service identity e o acesso ao Firestore;
4. restaurar a upload keystore a partir de backup criptografado;
5. reconfigurar os secrets de release sem registrar seus valores;
6. reconstruir o release a partir da fonte de verdade.

A upload keystore precisa de **pelo menos dois locais independentes de backup criptografado**, e um deles deve ser restaurado/testado. A mera existência do arquivo não prova recuperação.

O drill final precisa de owner primário e um segundo contato autorizado distinto. Nenhum valor secreto é aceito como evidência no Git.

## 10. Owners, suporte e privacidade
Antes de PASS precisam existir valores reais para owner de release, contato secundário de recuperação, suporte público e contato de privacidade; o canal de suporte deve ser testado.

Blocker inclui perda de dados, impossibilidade ampla de jogar, falha sistêmica de entitlement ou incidente material de privacidade/segurança.

## 11. Hotfix/rollback
Toda correção publicada usa `versionCode` maior. Nunca exigir downgrade. Primeira publicação não finge rollback para versão pública inexistente; updates posteriores podem usar rollout progressivo conforme 12.8.

## 12. Handoff
Uma segunda pessoa autorizada deve conseguir localizar tag/commit/AAB/fingerprints, backups, Play Console, backend, documentos legais, proveniência, notices, procedimento de rebuild, suporte e hotfix sem depender de conhecimento oral exclusivo.

## 13. Ordem final de certificação
Na ancestry exata do release:
1. 12.8 certificado;
2. `release_input_scope_gate.py`;
3. `backend_dependency_evidence_gate.py --release`;
4. `android_dependency_inventory_gate.py --release`;
5. `third_party_notices_gate.py --release`;
6. `provenance_license_gate.py --release`;
7. `recovery_backup_drill_gate.py --release`;
8. `release_archive_gate.py --release`;
9. `continuity_support_gate.py --release`.

Enquanto runner, assets finais, addon/Gradle, AAB real, owners, recuperação e documentação final não existirem, **12.9 permanece em progresso**.

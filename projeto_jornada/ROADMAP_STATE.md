# Veredas da Trama — Estado Canônico do Roadmap

## Contrato de estado
- Título: **Veredas da Trama**; o produto não referencia o jogo externo usado como inspiração inicial.
- Direção visual: livro-jogo ilustrado à mão, nanquim/grafite, papel orgânico e paletas próprias dos 12 Domínios.
- Roadmap detalhado: `ROADMAP_MASTER.md`.
- `✅` exige PASS/evidência real persistida; `🟡` é implementação/preflight/evidência pendente; `⏳` é ainda não iniciado.
- Preparar código, contratos ou workflows **não aumenta a contagem formal**.

## Contagem formal
**110/130 passos concluídos.**

## Escopo de lançamento
- Idiomas: **pt_BR + en**; `es_419` preservado e adiado.
- Android application ID: **`com.pmartins87.veredasdatrama`**.
- Ponto final: **12.10 — projeto/build completos, testados e prontos para jogar, divulgar e publicar**.

## Fases 0–10
- **0.1–6.10: 10/10 ✅ em cada fase.**
- Fase 7: 7.1 ✅; 7.2 ✅; 7.3 🟡; 7.4 🟡; 7.5 🟡; 7.6 ✅; 7.7 ✅; 7.8 🟡; 7.9 ✅; 7.10 ⏳. Pendências principais: arte final 7.3–7.5 e áudio/música final 7.8 (`DEP-078-AUDIO`).
- **8.1–8.10 ✅.**
- **9.1–9.10 ✅.**
- **10.1–10.10 ✅ e congelada** em `BALANCE_FREEZE.json`.

## Fase 11 — QA, otimização e localização
- 11.1 ✅ — regressão/integração ampla; 288 jornadas completas.
- 11.2 ✅ — fuzzing/migração/corrupção de saves.
- 11.3 🟡 — automação/emuladores verdes; falta soak físico >=1.800 s (`DEP-113-PHYSICAL`).
- 11.4 ✅ — responsividade/acessibilidade.
- 11.5 ✅ — arquitetura de localização; fonte/fallback `pt_BR`, launch `pt_BR + en`.
- 11.6 🟡 — pack inglês físico íntegro; UI **131/131 pt_BR + 131/131 en**; execução conjunta pack/qualidade/arquitetura/linguística/overflow/iconografia/regressões ainda pendente.
- 11.7 🟡 — QA audiovisual real; faltam assets finais, incluindo 38 referências de áudio.
- 11.8 ✅ — zero blocker/critical ativo; `BILL-124-001` foi descoberto depois e permanece resolvido.
- 11.9 🟡 — 128 pause/resume + 24 restart rounds preparados; execução real pendente.
- 11.10 🟡 — RC final da Fase 11. Exige 11.3/11.6/11.7/11.8/11.9 certificados **e versão Android pública congelada**. O workflow usa Godot 4.7.1 validado pelo SHA-256 oficial, verifica os dois workflows críticos por Git blob, recertifica gates e só após árvore limpa cria `QA_11_10_COMPLETION.json` + `QA_11_10_RELEASE_INPUT_MANIFEST.json`. O manifesto certifica runtime/build **e 14 scripts críticos de controle de release**. Código, conteúdo, versão, preset, `mobile/`, gate crítico ou workflow pinado que mude depois exige novo 11.10.

### Infraestrutura de execução
Último probe: GitHub Actions terminou antes do primeiro step com `runner_id=0`, `steps=[]` e runner vazio. Isso é **não execução de infraestrutura**, não PASS/FAIL do produto. Não rerodar sem indício de recuperação.

## Fase 12 — publicação e release
- 12.1 🟡 — **Veredas da Trama** segue candidato; reconnaissance pública sem colisão exata relevante, mas INPI/WIPO/handles/domínios e clearance jurídico final continuam pendentes.
- 12.2 🟡 — package/versionamento/assinatura. Application ID e toolchain persistidos. `0.1.0-dev`/code 1 continuam desenvolvimento; alvo público `1.0.0`. `release_version_identity_gate.py --release` exige semver público congelado e versionCode confirmado livre no Play antes do 11.10 final. Upload key e Play app-signing key são identidades distintas: upload RSA >=2048 com validade >=25 anos; app signing gerenciada pelo Google Play, fingerprint SHA-256 público e validade além de 2033-10-22. Keystore/segredos privados nunca viram evidência. Faltam chaves/backups/secrets/Play App Signing/fingerprints/validades/versionCode/freeze real.
- 12.3 🟡 — privacidade/Data Safety/termos/classificação. Runtime legal bilíngue, minimização de Billing e retenção Firestore 730/30/7 implementadas. Preflight IARC/público-alvo é fail-closed e não prevê idade: 13 categorias exigem revisão humana do conteúdo final; abaixo de 13 exige revisão Famílias e 13–17 exige revisão específica de menor/privacidade/compras/marketing. Faltam deploy/TTL real, URLs/contato, revisão legal, revisão audiovisual final, IARC real, Data Safety e Console.
- 12.4 🟡 — Billing. Cliente/runtime + backend de referência, ProductPurchaseV2, correlação, acknowledgement/refetch, estado monotônico, retenção e gates implementados. Faltam addon 3.3.0 real, produtos Play, backend HTTPS/ADC/Firestore+TTL/rate limit e testes reais PURCHASED/PENDING/restore/reinstall/refund/revogação/offline.
- 12.5 🟡 — store listing. Copy PT-BR/en-US pronta (**1319/1207** chars), coerência comercial cruzada e contrato de 12 screenshots reais 1080×1920 com SHA-256/proveniência. Faltam ícone/feature graphic finais, 12 capturas do conteúdo certificado, gates executados e upload/inspeção no Play Console.
- 12.6 🟡 — AAB final. 11.10 → release usa **HEAD certificado ancestral + fingerprint runtime/build/control idêntico**, não “mesmo commit literal”; isso permite somente commits posteriores de evidência/Console. `release_workflow_integrity_gate.py` fixa os blobs QA `c8bea820…` e AAB `c43206c3…`; 14 scripts críticos participam do fingerprint. Godot engine, export templates e bundletool 1.18.3 têm digests oficiais pinados. O AAB real será inspecionado por bundletool (package/version/minSdk/targetSdk/debuggable/permissões), `jarsigner -strict`, certificado extraído do próprio AAB e SHA-256 da upload key. Faltam prerequisites reais, addon/Gradle final, AAB assinado, execução dos gates, inventário `releaseRuntimeClasspath`, rebuild equivalence, auditoria de payload e aceitação Play.
- 12.7 🟡 — teste interno/fechado; baseline >=12 testers por >=14 dias contínuos, evidência real pendente.
- 12.8 🟡 — go/no-go/rollback; depende 11.10 + 12.1–12.7 certificados, identidade de inputs/artefato, zero blockers e dry run.
- 12.9 🟡 — continuidade/suporte/proveniência/licenças. Pipeline backend lock/SBOM, inventário Android, notices e arquivo canônico preparados; faltam execução runner/Gradle final, revisão de direitos/licenças, notices finais, tag/AAB, owners, backups/recovery e handoff.
- 12.10 🟡 — FINAL. PASS somente quando 12.8/12.9 e toda identidade tag/commit/version/AAB/signing/archive/smoke/store/privacy/Billing/support/rollback coincidirem, com `ready_to_play`, `ready_to_promote`, `ready_to_publish` verdadeiros e decisão `go`.

## Cadeia 11.10 → 12.6 congelada
1. Antes do PASS 11.10, versão pública/versionCode são congelados.
2. 11.10 verifica o blob dos workflows críticos e os 14 scripts de controle que entrarão no fingerprint.
3. 11.10 gera o manifesto dos inputs runtime/build/control e grava seu aggregate SHA-256 no completion.
4. O release posterior deve ter o HEAD 11.10 como ancestral e o **mesmo aggregate SHA-256**; assinatura/Console metadata pode mudar porque fica deliberadamente fora do fingerprint.
5. Qualquer mudança no jogo, conteúdo, versão, export, `mobile/`, controles críticos ou workflows pinados invalida a linhagem e requer novo 11.10.
6. O AAB é então validado por identidade efetiva, permissões, assinatura, signer e SHA-256 antes de poder virar evidência de 12.6.

## Blockers/dependências reais
1. Aparelho físico para 11.3.
2. Executor funcional para 11.6/11.9/11.10 e suítes 12.x.
3. Assets finais de arte/áudio para Fase 7, 11.7, classificação e store.
4. 12.2: upload keystore + backups, protected secrets, Play App Signing, fingerprints/validades, versionCode livre e freeze `1.0.0` antes do 11.10 final.
5. Play Console, addon Billing, AAB real e backend de produção (HTTPS, Play API/ADC, Firestore TTL, rate limit e auditoria).
6. Revisão de conteúdo/público-alvo e IARC real.
7. Test track real 12.7.
8. Store: 12 screenshots Android reais + icon/feature graphic finais.
9. Continuidade final: lock/SBOM, inventário Android, notices/licenças, direitos dos assets, arquivo, owners/recovery/handoff.
10. Due diligence final do nome e documentação pública/legal.

## Regra de avanço
- Não repetir diagnóstico de blocker conhecido sem nova evidência.
- Avançar qualquer trabalho independente que reduza risco de release.
- Nunca aumentar **110/130** por preflight; somente por PASS real persistido.

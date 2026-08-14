# Veredas da Trama — Estado Canônico do Roadmap

## Contrato de estado
- Título: **Veredas da Trama**; o produto não referencia o jogo externo usado como inspiração inicial.
- Direção visual: livro-jogo ilustrado à mão, nanquim/grafite, papel orgânico e paletas próprias dos 12 Domínios.
- Roadmap detalhado: `ROADMAP_MASTER.md`.
- `✅` exige PASS/evidência real persistida; `🟡` é implementação/preflight/evidência pendente; `⏳` é ainda não iniciado.
- Preparar código, contratos ou workflows **não aumenta a contagem formal**.

## Contagem formal
**112/130 passos concluídos.**

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
- 11.6 ✅ — certificação composta no mesmo HEAD: pack inglês reprodutível, **19.100/19.100 unidades publicáveis em inglês**, zero faltantes, zero erros de token/terminologia, sanity linguístico, fallback 11.5, overflow, iconografia e regressão responsiva verdes. Evidência: `LOCALIZATION_11_6_COMPLETION.json`.
- 11.7 🟡 — QA audiovisual real; faltam assets finais, incluindo 38 referências de áudio.
- 11.8 ✅ — zero blocker/critical ativo; `BILL-124-001` foi descoberto depois e permanece resolvido.
- 11.9 ✅ — reliability soak real em runner hospedado: 128 ciclos pause/resume, 24 restart rounds, 153 reloads e 155 auditorias de integridade; baselines mobile/save/run-state preservados. Evidência: `RELIABILITY_11_9_COMPLETION.json`.
- 11.10 🟡 — RC final da Fase 11. Exige 11.3/11.6/11.7/11.8/11.9 certificados **e versão Android pública congelada**. O workflow usa Godot 4.7.1 validado pelo SHA-256 oficial, verifica os dois workflows críticos por Git blob, recertifica gates e só após árvore limpa cria `QA_11_10_COMPLETION.json` + `QA_11_10_RELEASE_INPUT_MANIFEST.json`. O manifesto certifica runtime/build **e 14 scripts críticos de controle de release**. Código, conteúdo, versão, preset, `mobile/`, gate crítico ou workflow pinado que mude depois exige novo 11.10.

### Infraestrutura de execução
GitHub Actions voltou a executar em runner hospedado após `pmartins87/Veredas` tornar-se público. O probe mínimo que antes terminava com `runner_id=0` passou a receber runner real e concluir os steps; 11.6 e 11.9 foram então executados e certificados. Jobs históricos sem runner permanecem classificados apenas como **não execução de infraestrutura**, nunca como PASS/FAIL do produto. O fan-out de CI deve permanecer controlado; certificações finais devem preferir workflows compostos/dirigidos em vez de dezenas de runs por commit.

## Fase 12 — publicação e release
- 12.1 🟡 — **Veredas da Trama** segue candidato; reconnaissance pública sem colisão exata relevante, mas INPI/WIPO/handles/domínios e clearance jurídico final continuam pendentes.
- 12.2 🟡 — package/versionamento/assinatura. Application ID e toolchain persistidos. `0.1.0-dev`/code 1 continuam desenvolvimento; alvo público `1.0.0`. `release_version_identity_gate.py --release` exige semver público congelado e versionCode confirmado livre no Play antes do 11.10 final. Upload key e Play app-signing key são identidades distintas: upload RSA >=2048 com validade >=25 anos; app signing gerenciada pelo Google Play, fingerprint SHA-256 público e validade além de 2033-10-22. Keystore/segredos privados nunca viram evidência. Faltam chaves/backups/secrets/Play App Signing/fingerprints/validades/versionCode/freeze real.
- 12.3 🟡 — privacidade/Data Safety/termos/classificação. Runtime legal bilíngue, minimização de Billing e retenção Firestore 730/30/7 implementadas. Preflight IARC/público-alvo é fail-closed e não prevê idade: 13 categorias exigem revisão humana do conteúdo final; abaixo de 13 exige revisão Famílias e 13–17 exige revisão específica de menor/privacidade/compras/marketing. Faltam deploy/TTL real, URLs/contato, revisão legal, revisão audiovisual final, IARC real, Data Safety e Console.
- 12.4 🟡 — Billing. Cliente/runtime + backend de referência, ProductPurchaseV2, correlação, acknowledgement/refetch, estado monotônico, retenção e gates implementados. Faltam addon 3.3.0 real, produtos Play, backend HTTPS/ADC/Firestore+TTL/rate limit e testes reais PURCHASED/PENDING/restore/reinstall/refund/revogação/offline.
- 12.5 🟡 — store listing. Copy PT-BR/en-US pronta (**1319/1207** chars), coerência comercial cruzada e contrato de 12 screenshots reais 1080×1920 com SHA-256/proveniência. Faltam ícone/feature graphic finais, 12 capturas do conteúdo certificado, gates executados e upload/inspeção no Play Console.
- 12.6 🟡 — AAB final. 11.10 → release usa **HEAD certificado ancestral + fingerprint runtime/build/control idêntico**, não “mesmo commit literal”; isso permite somente commits posteriores de evidência/Console. `release_workflow_integrity_gate.py` fixa os blobs QA `d00e8662…` e AAB `c43206c3…`; 14 scripts críticos participam do fingerprint. Godot engine, export templates e bundletool 1.18.3 têm digests oficiais pinados. O AAB real será inspecionado por bundletool (package/version/minSdk/targetSdk/debuggable/permissões), `jarsigner -strict`, certificado extraído do próprio AAB e SHA-256 da upload key. Faltam prerequisites reais, addon/Gradle final, AAB assinado, execução dos gates, inventário `releaseRuntimeClasspath`, rebuild equivalence, auditoria de payload e aceitação Play.
- 12.7 🟡 — teste interno/fechado; baseline >=12 testers por >=14 dias contínuos, evidência real pendente.
- 12.8 🟡 — go/no-go/rollback; depende 11.10 + 12.1–12.7 certificados, identidade de inputs/artefato, zero blockers e dry run.
- 12.9 🟡 — continuidade/suporte/proveniência/licenças. Pipeline backend lock/SBOM, inventário Android, notices e arquivo canônico preparados; faltam execução das evidências finais/Gradle final, revisão de direitos/licenças, notices finais, tag/AAB, owners, backups/recovery e handoff.
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
2. Assets finais de arte/áudio para Fase 7, 11.7, classificação e store.
3. 12.2: upload keystore + backups, protected secrets, Play App Signing, fingerprints/validades, versionCode livre e freeze `1.0.0` antes do 11.10 final.
4. Play Console, addon Billing, AAB real e backend de produção (HTTPS, Play API/ADC, Firestore TTL, rate limit e auditoria).
5. Revisão de conteúdo/público-alvo e IARC real.
6. Test track real 12.7.
7. Store: 12 screenshots Android reais + icon/feature graphic finais.
8. Continuidade final: lock/SBOM, inventário Android, notices/licenças, direitos dos assets, arquivo, owners/recovery/handoff.
9. Due diligence final do nome e documentação pública/legal.

## Regra de avanço
- Não repetir diagnóstico de blocker conhecido sem nova evidência.
- Avançar qualquer trabalho independente que reduza risco de release.
- Nunca aumentar **112/130** por preflight; somente por PASS real persistido.

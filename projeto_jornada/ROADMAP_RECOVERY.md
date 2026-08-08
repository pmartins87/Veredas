# Recuperação do Roadmap — registro de integridade

## Motivo
O projeto sempre foi conduzido como um roadmap finito de **130 passos**, numerados de 0.1 a 12.10. Durante as primeiras rodadas, parte desse roadmap existiu apenas no armazenamento temporário da sessão. Quando a persistência foi transferida para a branch `projeto-jornada-snapshots`, o texto detalhado das fases 8–12 já não estava disponível.

## Verificação realizada em 2026-08-07/08
1. A branch canônica foi percorrida até o commit mais antigo próprio do projeto.
2. O primeiro commit da branch é `143b805e8a658b4268475a023cef32add9357040`, mensagem `Persist canonical roadmap and original product identity`.
3. A árvore desse commit contém somente `README.md` e `projeto_jornada/ROADMAP_STATE.md`; não contém `ROADMAP_MASTER`, arquivo arquivado ou documentação com 8.1–12.10.
4. A branch inteira deriva diretamente de `main`; não há histórico anterior do jogo no repositório-base.
5. A recuperação por contexto conversacional confirmou apenas a existência do roadmap de 130 passos e o ponto final, mas não devolveu os títulos literais de 8.1–12.10.

## Regra adotada
Não afirmar que a redação perdida foi recuperada.

O arquivo `ROADMAP_MASTER.md` preserva integralmente:
- a numeração 0.1–12.10;
- os passos 0–7 que já haviam sido explicitados na conversa;
- as metas quantitativas e qualitativas já aprovadas;
- o ponto final 12.10 já definido: projeto e build finais, testados, empacotados e prontos para jogar, divulgar e publicar.

As fases 8–12 recebem **redação restaurada**, baseada exclusivamente nos critérios de conclusão já estabelecidos ao longo do projeto:
- Android funcional e experiência mobile;
- metaprogressão e produto/monetização final sem pay-to-win;
- balanceamento por simulação e testes;
- QA, performance, acessibilidade e localização;
- material de loja, documentação, Release Candidate e publicação.

Essa restauração não altera o número de passos, não cria uma fase extra e não encurta nenhum gate de qualidade.

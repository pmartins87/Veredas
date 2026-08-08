# Fase 10.2 — Balanceamento dos 36 Andarilhos

## Objetivo

Certificar que os 36 Andarilhos oferecem identidades táticas distintas sem criar progressão vertical disfarçada, personagens objetivamente dominantes ou curvas de aprendizado que recompensem jogo aleatório acima do domínio do kit.

## Contrato horizontal

- Todos os 36 começam com 16 Vida e 8 Vigor.
- Diferenças vivem em Postura, Guarda, recurso de assinatura, custo/potência das habilidades e interação entre mecânicas.
- Cada Domínio contém um Andarilho approachable, um intermediate e um expert.
- Cada personagem possui duas habilidades de assinatura e uma assinatura de balanceamento própria.

## Mecânicas certificadas

As 72 habilidades cobrem 12 famílias com efeito observável no runtime: damage, posture, guard, heal, move, status, counter, resource, echo, mark, debt e range.

## Metodologia estatística

O gate executa três níveis de política por personagem:

- novice: política random;
- competent: política balanced;
- learned: política recomendada pelo próprio kit.

A comparação de poder entre os três Andarilhos de um mesmo Domínio usa exclusivamente a política **balanced** para todos. Isso isola o poder do kit do comportamento macro de políticas como cautious, aggressive ou explorer.

A curva de aprendizado continua sendo medida separadamente por novice → competent → learned, portanto a política recomendada ainda precisa demonstrar valor sem ser usada como variável de confusão no teste de poder relativo.

## Tamanho da amostra

O gate permanente usa 12 seeds por nível de habilidade, totalizando:

36 personagens × 3 níveis × 12 seeds = **1.296 jornadas completas**.

As mesmas seeds ambientais são reutilizadas entre os níveis de habilidade de um mesmo personagem para reduzir ruído na comparação.

## Regra de ajuste

Limiar estatístico não é afrouxado para obter PASS. Primeiro se distingue:

1. erro de runtime ou política;
2. viés metodológico;
3. ruído amostral;
4. outlier real de kit.

Somente o quarto caso justifica nerf/buff direcionado. Os primeiros ajustes direcionados confirmados foram Vigia de Maré e Peregrina da Sede, detectados como outliers mesmo sob política balanced controlada.

A Fase 10.2 só é considerada concluída quando `CHARACTER_BALANCE_CERTIFICATION PASS: 10.2` é emitido pela CI canônica após todos os gates anteriores também passarem.

# Veredas da Trama — Reconstrução Canônica e Verificação

Este arquivo define a sequência única para reconstruir o projeto a partir da branch persistente `projeto-jornada-snapshots`.

## 1. Reconstruir todo o catálogo

Na raiz `projeto_jornada`:

```bash
python tools/rebuild_content.py
```

O comando deve gerar em `data/` exatamente:

- 12 mundos
- 120 localidades
- 96 famílias de criaturas
- 300 monstros
- 60 chefes/subchefes
- 1.116 itens
- 300 NPCs
- 204 Marcas
- 120 Dívidas Narrativas
- 36 personagens
- 72 habilidades exclusivas
- 2.544 eventos
- 36 finais
- 144 pools

Total esperado: **5.160 registros**.

## 2. Auditar estrutura e autenticidade

```bash
python tools/validate_canonical.py
```

O gate exige, além das contagens:

- IDs ASCII válidos e sem duplicação;
- referências internas íntegras;
- pelo menos 80% de estruturas narrativas normalizadas únicas;
- pelo menos 400 assinaturas distintas de escolhas;
- ao menos 250 ecologias distintas;
- ao menos 250 perfis de contrajogo;
- diversidade mínima de objetivos, pressões e vozes de NPCs;
- nenhum item com nome-placeholder;
- 36 passivas e 36 fraquezas distintas;
- ao menos 70 assinaturas mecânicas entre as 72 habilidades;
- todo chefe com pelo menos três fases.

Baseline verificado no ambiente de produção em 2026-08-07:

- registros: **5.160**
- estruturas narrativas normalizadas únicas: **88,719%**
- assinaturas de escolhas: **1.028**
- erros estruturais: **0**

## 3. Preparar assets da Fase 7

```bash
python tools/prepare_phase7.py
```

O pipeline constrói/valida manifests e os assets vetoriais reproduzíveis. As grandes ilustrações desenhadas continuam sendo assets de produção final e não são falsamente substituídas por placeholders.

## 4. Importar na Godot

Versão-alvo congelada: **Godot 4.7.1 stable**, renderer Compatibility, viewport-base 540×960, orientação vertical.

Abrir `project.godot` uma vez para importar SVGs, shader e demais recursos.

## 5. Certificar runtime

Em ambiente com Godot disponível:

```bash
godot --headless --path . res://tests/runtime_smoke.tscn
```

O smoke test verifica:

- carregamento das quotas centrais de conteúdo;
- RNG determinístico;
- criação de jornada;
- seleção/aplicação de evento;
- combate telegráfico;
- atlases vetoriais;
- paletas de Domínio;
- shader de pergaminho;
- save/load com roundtrip.

Somente um PASS real nesse teste (e nos testes específicos posteriores) permite certificar formalmente os gates 1.10, 2.10, 3.10 e 4.10.

## Regra de continuidade

A branch persistente é a fonte de verdade. O filesystem temporário de uma sessão nunca deve ser considerado a única cópia canônica do projeto.

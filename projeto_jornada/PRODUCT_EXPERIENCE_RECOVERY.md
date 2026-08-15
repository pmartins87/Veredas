# Veredas da Trama — Recuperação da Experiência de Produto

## Por que este plano existe

Em 2026-08-14, o primeiro playtest humano em Android físico demonstrou que a build então usada para QA era tecnicamente funcional, mas **não representava um jogo aceitável**. Ela apresentava interface plana, ausência dos assets finais, textos formados por recombinação de fragmentos, escolhas sem intenção dramática clara, rótulos internos/inglês vazando no PT-BR e encerramento sem payoff narrativo.

Esse resultado invalida a suposição anterior de que volume de conteúdo + cobertura estrutural + testes automatizados eram evidência suficiente de qualidade. Não eram.

O blocker canônico é `EXP-001` em `qa/known_issues.json`.

## Classificação da build rejeitada

A APK usada no primeiro teste físico passa a ser classificada como **harness técnico**. Ela ainda pode ter valor para regressões mecânicas históricas, mas:

- não é release candidate;
- não é referência visual;
- não é referência narrativa;
- não deve ser usada para screenshots de loja;
- não deve consumir um soak físico de 30 minutos;
- não deve ser apresentada novamente como aproximação da experiência final.

## Mudança de método

### Antes

O pipeline industrial criava milhares de registros a partir de pools de:

- localidade;
- material;
- perigo;
- segredo;
- sensação;
- stake;
- verbo de escolha;
- categoria de evento.

Isso é útil para **variação**, mas foi usado perto demais da superfície final. O resultado podia ser sintaticamente válido, estatisticamente diverso e localizável, mas semanticamente artificial.

### Agora

O conteúdo final passa a usar o modelo:

**espinha autoral → cenas autorais → variantes contextuais → procedimento/combate → callbacks → desfecho autoral**.

Proceduralidade fica subordinada à história. Ela pode variar detalhes, encontros secundários, recursos, caminhos e consequências parametrizadas, mas **não pode inventar a função dramática da cena combinando slots**.

## Marco de recuperação: Golden Vertical Slice — Mata do Fio Verde

Nenhum trabalho de release é caminho crítico até esta slice ser aprovada.

A slice deve durar aproximadamente **10–20 minutos** em uma primeira jornada e conter, no mínimo:

1. **Abertura/hook concreto** — o jogador entende imediatamente quem é, onde está e por que precisa agir.
2. **Um protagonista jogável reconhecível** — nome, voz, habilidade/limitação e motivo pessoal perceptíveis em jogo.
3. **Um NPC nomeado** — personalidade, desejo próprio e relação real com o problema; não apenas fornecedor de texto.
4. **Uma localidade memorável** — a Mata deve parecer um lugar, não uma lista de substantivos temáticos.
5. **Um mistério compreensível** — pergunta que gere curiosidade e seja alimentada por pistas, não por frases abstratas.
6. **Exploração com descoberta** — informação ou recurso que altere o entendimento/decisão posterior.
7. **Conflito jogável** — combate, fuga, negociação ou risco sistêmico em que mecânica e narrativa expliquem uma à outra.
8. **Escolha significativa** — opções representam intenções realmente diferentes, com custo e consequência entendíveis.
9. **Callback visível** — algo feito anteriormente retorna e muda uma cena posterior.
10. **Desfecho narrativo** — a jornada termina com consequência, revelação ou resolução parcial; nunca apenas com contadores como `Resultado: defeat`.

## Padrão de escrita

Cada cena publicável precisa responder, em linguagem humana, a cinco perguntas:

- **Quem quer o quê?**
- **O que impede isso agora?**
- **Por que o jogador deve se importar?**
- **O que muda quando ele escolhe?**
- **O que esta cena prepara ou paga depois?**

Se uma cena não responder a pelo menos as quatro primeiras, ela não é conteúdo final.

### Escolhas

Escolhas não podem ser construídas como:

`verbo + substantivo do pool + frase de stake`.

Cada opção deve representar uma intenção legível, por exemplo:

- proteger alguém assumindo um risco;
- obter informação ao custo de tempo;
- violar um tabu para ganhar vantagem;
- abandonar uma pessoa para preservar um recurso.

O texto da opção pode ser curto, mas a consequência precisa ser distinta no estado do jogo.

### Taxonomia interna

Categorias como `Hazard`, `Callback`, `Creature`, `defeat`, IDs e nomes de enumeração **nunca podem aparecer diretamente na superfície do jogador**. Se uma categoria tiver equivalente editorial, ela recebe copy localizada própria; caso contrário, permanece invisível.

## Personagens

A primeira slice não precisa exibir os 36 personagens. Ela precisa provar **um personagem de verdade**.

O personagem-piloto deve ter:

- nome e silhueta/portrait próprios;
- objetivo pessoal;
- pelo menos uma habilidade que altere decisões ou combate;
- pelo menos uma reação exclusiva em diálogo/narração;
- um ponto de tensão ou fraqueza;
- um pequeno arco dentro da slice.

Depois da aprovação, o padrão é escalado para os demais personagens.

## Arte

O estilo aprovado permanece:

- dark fantasy original;
- ilustração à mão / gravura / nanquim e grafite;
- papel e matéria orgânica;
- forte contraste de forma;
- cada Domínio com paleta própria;
- inspiração na linguagem visual de livros-jogo clássicos, sem copiar IP, composição ou assets de jogos de referência.

A Golden Slice deve usar **arte representativa do padrão final**, não retângulos bege como substituto. Conjunto mínimo:

- 1 key art/background da Mata do Fio Verde;
- 3–5 ilustrações de localidades/cenas;
- portrait/silhueta final-style do personagem-piloto;
- 1–2 NPCs nomeados;
- pelo menos 1 inimigo/ameaça ilustrada;
- ornamentos de UI, ícones e molduras coerentes;
- estados visuais claros para risco, consequência e transição.

A arte usada na slice pode ser posteriormente refinada, mas deve ser boa o bastante para julgar a experiência real.

## Áudio

A slice deve ser audível antes de novo playtest qualitativo:

- 1 música/tema da Mata;
- 1 ambiência da Mata;
- UI SFX essenciais;
- escolha/confirmação;
- dano/impacto quando aplicável;
- transição/consequência.

Não é necessário concluir todos os 38 assets para avaliar a Golden Slice, mas **silêncio total deixa de ser aceito como build representativa**.

## UI/UX

A tela deve parecer um livro-jogo ilustrado interativo, não um painel administrativo.

Requisitos da slice:

- arte ou composição visual dominante antes do bloco textual quando a cena permitir;
- tipografia com hierarquia editorial clara;
- corpo de texto confortável e menor que o título, sem blocos desnecessariamente grandes;
- escolhas visualmente separadas da narração;
- HUD reduzido ao que ajuda a decisão atual;
- informação meta detalhada deslocada para telas secundárias;
- modal de acessibilidade com contraste real, fechamento claro e scroll correto;
- end screen narrativo, com estatísticas como informação secundária.

## Gate humano obrigatório

Antes de escalar a nova abordagem para os 12 Domínios, a Golden Slice será instalada em Android físico e avaliada por uma pessoa que **não está lendo JSON, roadmap ou documentação durante o teste**.

Perguntas de aceite:

1. Você entende o que está acontecendo e o que seu personagem quer?
2. Algum personagem ou situação despertou curiosidade?
3. As escolhas parecem diferentes entre si e você entende o risco de cada uma?
4. O jogo parece visualmente vivo e intencional, não protótipo/debug?
5. Arte, texto, interface e som parecem pertencer ao mesmo mundo?
6. O final da slice dá vontade de descobrir o que acontece depois?

Para fechar `EXP-001`, não pode haver blocker/critical nessas dimensões. Feedback major pode gerar iteração adicional sem mascaramento.

## Efeito no roadmap existente

O roadmap continua **finito em 130 passos**. Não adicionamos uma fase infinita de retrabalho; fortalecemos os critérios dos passos existentes:

- **6.1 reaberto** — reautoria da Mata/Várzea, começando pela Golden Slice da Mata;
- **6.10 reaberto** — auditoria de conteúdo artificial passa a incluir avaliação semântica e humana;
- **7.3–7.5 pendentes** — produção visual real;
- **7.8/7.10 pendentes** — áudio e integração audiovisual;
- **11.4 reaberto** — UI/acessibilidade em contexto físico real;
- **11.6 reaberto** — QA linguístico inclui superfície-fonte PT-BR e coerência semântica em contexto;
- **11.8 reaberto** — `EXP-001` impede zero-blocker;
- **11.3 suspenso** — só retorna depois de uma nova build representativa;
- **11.9 histórico** — reliability deve ser rerodada após a reautoria antes do RC;
- **11.10 bloqueado** — nenhuma candidata anterior é representativa.

## Ordem de execução

1. Construir a espinha narrativa da Golden Slice.
2. Implementar dados autorais separados dos geradores industriais atuais.
3. Integrar o fluxo da primeira jornada para privilegiar essa espinha.
4. Corrigir vazamentos de taxonomia e copy de derrota/desfecho.
5. Redesenhar a apresentação das cenas e do Nó de Vigília.
6. Integrar conjunto audiovisual representativo.
7. Rodar gates mecânicos existentes sem enfraquecê-los.
8. Fazer novo playtest humano curto da Golden Slice.
9. Iterar até `EXP-001` poder ser fechado.
10. Só então escalar a autoria/proceduralidade híbrida e retomar soak/release.

## Regra de proteção contra recaída

A partir deste incidente, **nenhum PASS de conteúdo/UX/localização poderá ser justificado exclusivamente por contagem, schema, cobertura, ausência de overflow ou simulação**. Para superfícies vividas pelo jogador, a prova final inclui contexto real e avaliação humana.

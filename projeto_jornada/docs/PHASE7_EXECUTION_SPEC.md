# Veredas da Trama — Especificação de Execução da Fase 7

## 7.7 — Animações e VFX

Princípio: movimento discreto, artesanal e funcional. Nada de partículas 3D chamativas.

### Animações UI
- entrada de cartão: 120–180 ms, deslocamento curto + fade;
- confirmação de escolha: compressão de 4% + retorno;
- aquisição de Marca: símbolo é desenhado em 350–500 ms como tinta aparecendo no papel;
- Dívida Narrativa: fio fino conecta momentaneamente a escolha à Marca;
- dano: pequeno deslocamento de papel/tinta, sem shake excessivo;
- cura: lavagem verde/âmbar discreta;
- quebra de Postura: rachadura de tinta sobre a barra;
- mudança de Domínio: página/folha vira ou é atravessada por uma Vereda desenhada.

### VFX diegéticos
- Sangramento: mancha de tinta vermelha pequena;
- Queimadura: borda tostada local;
- Molhado: pigmento aquarelado espalha;
- Choque: riscos angulares de nanquim;
- Congelamento: traços cristalinos finos;
- Eco: duplicação deslocada da linha;
- Cinza: apagamento parcial da tinta;
- Ruptura: linha do desenho se parte e realinha.

## 7.8 — Áudio e música

Princípio: o som acompanha a leitura e nunca compete com o texto.

### Camadas
1. Ambiência de Domínio (loop longo e discreto).
2. Música temática adaptativa (poucas notas, instrumentos acústicos/orgânicos).
3. SFX de interface (papel, pena, couro, madeira, metal leve).
4. SFX de combate (impactos secos, respiração, ambiente).
5. Motivos de Trama/Eco (assinaturas sonoras recorrentes).

### Identidade musical dos Domínios
- Mata: madeira, cordas dedilhadas, sopros graves, água distante.
- Várzea: percussão líquida, cordas harmônicas, ressonâncias invertidas.
- Costa: sinos de bronze, vento, cordas tensas.
- Chapada: percussão seca, cordas curtas, drones quentes.
- Salinas: silêncio amplo, pedras, cordas espaçadas, vocalizações distantes.
- Vértice: vento, sinos leves, cordas agudas tensionadas.
- Forja: metal percussivo controlado, pulsos graves.
- Cinza: ruído de papel/cinza, notas isoladas, silêncio expressivo.
- Iscara: harmônicos, cristais, cordas longas, aurora sonora.
- Portas: motivos interrompidos, instrumentos que mudam de espaço/reverb.
- Arquivo: pena/papel, madeira, pequenos sinos, repetição variada.
- Tear: combinação fragmentada de motivos dos outros Domínios.

## 7.9 — Acessibilidade audiovisual

Obrigatório:
- escala de fonte configurável;
- contraste alto opcional;
- nunca depender apenas de cor;
- símbolos + texto para estados;
- opção de reduzir/anular animações;
- opção de desativar tremor e flashes;
- legendas textuais para informação sonora relevante;
- navegação por foco e leitor de tela onde suportado;
- áreas de toque mínimas de 48 dp;
- escolha de velocidade de texto/efeitos;
- interface utilizável sem áudio;
- combate compreensível por texto e ícones, não por animação.

## 7.10 — Integração e QA audiovisual

Gate final da Fase 7:
- 100% dos IDs do manifest visual resolvem para assets existentes;
- nenhum asset contém marca/nome de referência externa;
- contraste funcional ≥ 4.5:1 para texto normal;
- nenhuma informação essencial depende só de cor;
- todos os 12 Domínios são reconhecíveis em teste cego de paleta/motivos;
- todos os 36 personagens têm silhueta distinguível;
- todas as 96 famílias de monstros possuem linguagem visual distinguível;
- chefes têm leitura clara das três fases;
- UI permanece legível em telas pequenas;
- opções de redução de movimento funcionam;
- mix de áudio não mascara texto/feedback;
- assets carregam sem referências quebradas;
- memória e tamanho do pacote ficam dentro do orçamento definido na Fase 10.

## Estado
Este documento fecha a especificação da Fase 7. Ele não certifica 7.3–7.10; a conclusão exige assets e integração reais.

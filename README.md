# RVBL-2 — Núcleo RISC-V RV32I_Zmmul_Xicrc

Processador multiciclo para o **ChampionCHIP eXperience 2026 — Fase 2**, plataforma ChipInventor RVBL-2.

Implementa as 47 instruções do conjunto exigido: RV32I base, extensão Zmmul (multiplicação) e extensão Xicrc (CRC).

## Estrutura

```
Books/				Livros
rtl/                		RTL sintetizável, um diretório por módulo
  include/          		rvbl2_defines.vh — constantes compartilhadas
  control/          		unidade de controle (FSM)
  pc/  ir/          		contador de programa e registrador de instrução
  alu/ mult/ crc/   		aritmética e extensões
  regfile/ imm/ branch_cmp/
  lsu/ imem/ dmem/ addr_decoder/
  top/              		topo do núcleo — sem lógica própria
tb/                 		testbenches, um diretório por módulo
docs/               		tabelas de especificação e contratos de interface
fw/                 		firmwares de teste
sim/                		saídas de simulação (não versionadas)
synth/              	configuração do OpenLane
```

## Regra do arquivo de constantes

`rtl/include/rvbl2_defines.vh` é a **única fonte** para qualquer número que atravesse
a fronteira entre dois módulos: opcodes, funct3, funct7, códigos de seleção da ULA, do
multiplicador e do CRC, codificação dos muxes, estados da FSM e mapa de memória.

Nenhum módulo redefine esses valores como `localparam` próprio. Todo módulo começa com:

```verilog
`include "rvbl2_defines.vh"
```

Antes de alterar valores no arquivo defines as mudanças precisam do aval de todos os membros antes do commit.

## Convenção dos testbenches



## Estado atual

| Módulo | Situação |
|---|---|
| Unidade de Controle | implementada, 10 blocos de teste passando, sem latch inferido |
| PC / IR | pendente |
| ULA / MULT / CRC | em desenvolvimento |
| Regfile / Imm / Comparador | em desenvolvimento |
| LSU / IMEM / DMEM / Decodificador | em desenvolvimento |
| Topo | pendente |

## Decisões de arquitetura

Estão registradas em [`docs/CONTRATOS.md`](docs/CONTRATOS.md) e resumidas na seção 12 do
`rvbl2_defines.vh`. As duas que mais afetam outros módulos:

- **A1** — o PC guarda o endereço *da instrução* durante toda a execução dela; o `+4` vem de um
  somador dedicado, fora da ULA.?
- **B1** — não existem registradores intermediários (ALUOut / MDR); o caminho execute → write-back
  é combinacional.

## Referências

- ChampionChip Block Guide 2026, versão 1.0
- RISC-V Unprivileged ISA Specification

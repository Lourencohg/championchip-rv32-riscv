# Contratos de Interface entre Módulos

Esse arquvo registra as decisões acerca da comnicação de fronteira entre módulos.

Cada contrato tem um dono. Mudança em qualquer um deles exige aviso aos afetados **antes** do commit.

---

## A1 — Tratamento do contador de programa

**Decidido.** O PC guarda o endereço **da instrução** durante toda a execução dela. Não é
incrementado na busca; é escrito no último estado de cada instrução. Um somador dedicado de `+4`,
fora da ULA, alimenta a entrada `PC_SRC_PLUS4` do mux do PC **e** a entrada `RESULT_SRC_PC4` do mux
de write-back — é o mesmo fio.

**Motivo.** No RISC-V o alvo é `PC_da_instrução + imediato`. Incrementar na busca erraria o alvo em
4 bytes nos seis branches, no JAL e no AUIPC.

**Afeta:** Lourenço (PC, unidade de controle), Felipe (o valor de retorno do JAL/JALR é `PC+4`, não `PC`).


---

## B1 — Não existem registradores intermediários

<!-- **Decidido.** Não há ALUOut nem MDR. O caminho execute → write-back é combinacional, portanto a 
unidade de controle **mantém** os seletores da ULA, do multiplicador, do CRC e da memória durante
os estados de write-back.

**Consequência para Gabriel:** a saída da ULA, do multiplicador e do CRC **não deve ser registrada**.
Os três blocos são puramente combinacionais.

**Consequência para Maia:** a LSU não registra o dado do load. O endereço continua sendo
apresentado durante o write-back.

**Por que isso é crítico.** Se um módulo registrar sua saída e a unidade de controle assumir que não,
os dois passam em seus testbenches isolados e falham juntos na integração — com sintoma de "o
registrador recebeu o valor errado", que parece bug da ULA.
--> 
---

## C — Geração do byte write

<!-- **Decidido.** `bw_o` é gerado pela **LSU**, não pela unidade de controle.

**Base:** seção 3.3.2 do Block Guide afirma que "a LSU emite um sinal chamado *byte write*, de 4
bits". A própria LSU usa os 2 bits inferiores do endereço para reposicionar o dado.

**Afeta:** Maia.
-->
---

## D — Seleção do formato de imediato

<!-- **Decidido.** Não existe sinal `imm_sel`. O extensor de imediatos decodifica o opcode sozinho.

**Base:** seção 3.1.5 do Block Guide.

**Afeta:** Felipe.
-->
---

## E — Proteção do registrador x0
<!--
**Decidido.** x0 é protegido **dentro do banco de registradores**. A unidade de controle afirma
`reg_write` sem verificar `rd`.

**Base:** seção 3.1.4 do Block Guide — x0 é hardwired em zero.

**Afeta:** Felipe. Vetor de teste útil: `lw x0, 0(x2)`, que exercita exatamente essa guarda.
-->
---

## F — op_size: unidade de controle → LSU
<!--
**Decidido.** Passthrough puro do `funct3`. Tamanho em `[1:0]`, extensão de zeros em `[2]`:

| valor | instrução |
|---|---|
| `3'b000` | LB / SB |
| `3'b001` | LH / SH |
| `3'b010` | LW / SW |
| `3'b100` | LBU |
| `3'b101` | LHU |

**Base:** a porta `op_size_o [2:0]` é fixada pela Figura 3 do Block Guide, mas a **codificação não é
publicada**. Esta é escolha da equipe.
-->
**Afeta:** Maia (LSU), Lourenço (unidade de controle).

---

## G — Largura dos seletores da ULA

**Decidido.** `alu_src_a` e `alu_src_b` têm **1 bit cada**.

**Afeta:** Gabriel (portas da ULA), Felipe (muxes do datapath), Lourenço.

**Se A1 for revertida,** a constante 4 volta e `alu_src_b` passa a 2 bits.

---

## H — Deslocamento vem do operando B

**Decidido.** O `shamt` das operações de shift vem de `B[4:0]`, não de uma porta separada.

**Base:** Tabela 9 do Block Guide é explícita: `Q = A << B[4:0]`, `Q = A >> B[4:0]`,
`Q = A >>> B[4:0]`.

**Motivo prático:** o `shamt` do SLLI/SRLI/SRAI chega pelo imediato, e é o mux `alu_src_b` que faz
essa escolha. Uma porta separada não teria por onde recebê-lo.

**Afeta:** Gabriel.

---

## I — Codificação da ULA

**Fixada pelo Block Guide, Tabela 9.** 

| valor | operação | | valor | operação |
|---|---|---|---|---|
| `4'h0` | PASS_B | | `4'h6` | SLL |
| `4'h1` | ADD | | `4'h7` | SRL |
| `4'h2` | SUB | | `4'h8` | SRA |
| `4'h3` | AND | | `4'h9` | SLT |
| `4'h4` | OR | | `4'hA` | SLTU |
| `4'h5` | XOR | | | |

---

## J — Política para opcode ilegal
<!--
**Decidido.** No-op silencioso que avança o PC. O Block Guide não pede trap de instrução ilegal e a
tabela de cobertura das 47 instruções não tem linha para isso.
-->
---

## K — ECALL e EBREAK

**Decidido provisoriamente.** Ambos levam o núcleo ao estado de parada (`halt`).

**A confirmar** 

---

## PENDENTE — Temporização da IMEM

**Dono: Maia. Bloqueia: Lourenço.**

A busca ocupa **um** estado por assumir que a IMEM é ROM combinacional. O Block Guide afirma que a
DMEM é síncrona (seção 4.3) e **não diz o mesmo** da IMEM (seção 4.2) — é inferência, não fato.

Se a IMEM for síncrona, a busca passa a ocupar dois estados e **todas as contagens de ciclo mudam**:

| classe | ciclos hoje |
|---|---|
| ALU / MULT / CRC / LUI / AUIPC | 4 |
| load | 6 |
| store | 4 |
| branch | 3 |
| jump | 4 |

---
|---|---|---|
| — | A1, B1, C, D, E, F, G, H, I, J, K | Registro inicial |

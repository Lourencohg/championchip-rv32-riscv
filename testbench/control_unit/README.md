# Testbench da Unidade de Controle

Módulo de topo chamado `testbench`, como a plataforma ChipInventor exige (`-s testbench`).

Dez blocos de verificação:

1. Contagem de ciclos das 13 formas de instrução
2. As 11 operações da Tabela 9
3. Armadilhas: `addi` com imediato negativo, `srli` x `srai`, funct7 separando ADD/MUL/CRC
4. Branch tomado e não tomado
5. JAL x JALR no write-back do link
6. Estados de memória
7. `we_o` permanece em 0 durante todo o load
8. `op_size_o` para os 5 loads e os 3 stores
9. Habilitações do multiplicador e do CRC, e o LUI
10. ECALL x EBREAK x FENCE

Rodar: `make control` a partir da raiz do repositório.

**Pendente:** verificação independente escrita por Felipe a partir da tabela de sinais, conforme
previsto na S5 do plano. Este testbench foi escrito junto com a implementação e compartilha os
mesmos pontos cegos.

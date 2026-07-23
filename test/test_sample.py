import cocotb
from cocotb.triggers import RisingEdge, ReadOnly

from .helpers.setup import setup
from .helpers.memory import Memory
from .helpers.logger import logger
from .helpers.format import format_cycle


@cocotb.test()
async def test_store_constant(dut):

    # --------------------------------------------------
    # Program Memory
    # --------------------------------------------------
    program_memory = Memory(
        dut=dut,
        addr_bits=8,
        data_bits=16,
        channels=1,
        name="program"
    )

    program = [

        # CONST R0,#7  (DATA)
        0b1001000000000111,

        # CONST R1,#0  (ADDRESS)
        0b1001000100000000,

        # STR R1,R0
        0b1000000000010000,

        # RET
        0b1111000000000000,
    ]

    # --------------------------------------------------
    # Data Memory
    # --------------------------------------------------
    data_memory = Memory(
        dut=dut,
        addr_bits=8,
        data_bits=8,
        channels=4,
        name="data"
    )

    data = [0] * 16

    # --------------------------------------------------
    # Setup GPU
    # --------------------------------------------------
    await setup(
        dut=dut,
        program_memory=program_memory,
        program=program,
        data_memory=data_memory,
        data=data,
        threads=1
    )

    logger.info("===================================")
    logger.info("Initial Data Memory")
    logger.info("===================================")
    data_memory.display(16)

    # --------------------------------------------------
    # Run Simulation
    # --------------------------------------------------
    MAX_CYCLES = 100
    cycles = 0

    while dut.done.value != 1 and cycles < MAX_CYCLES:

        # Advance memory models
        data_memory.run()
        program_memory.run()

        await ReadOnly()

        # Existing formatted output
        format_cycle(dut, cycles)

        # Extra debug
        print(
            f"Cycle {cycles:02d} | "
            f"done={int(dut.done.value)}"
        )

        await RisingEdge(dut.clk)

        cycles += 1

  

    # --------------------------------------------------
    # Completed
    # --------------------------------------------------
    logger.info("-----------------------------------")
    logger.info(f"Kernel completed in {cycles} cycles")
    logger.info("-----------------------------------")

    logger.info("Final Data Memory")
    data_memory.display(16)

    print("\n========== FINAL MEMORY ==========")

    for i in range(16):
        print(f"MEM[{i:02}] = {data_memory.memory[i]}")

    print("==================================")

    # --------------------------------------------------
    # Verify Result
    # --------------------------------------------------
    assert data_memory.memory[0] == 7, \
        f"Expected memory[0] = 7, got {data_memory.memory[0]}"

    logger.info("✅ TEST PASSED")
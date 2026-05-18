# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge

############################################################
# SPI Utilities
############################################################

def set_ui_in_bit(dut, bit, value):
    if not hasattr(dut, "_ui_in_shadow"):
        dut._ui_in_shadow = 0

    dut._ui_in_shadow &= ~(1 << bit)
    dut._ui_in_shadow |= ((value & 1) << bit)

    dut.ui_in.value = dut._ui_in_shadow

def change_mosi(dut, mosi: int):
    set_ui_in_bit(dut, 0, mosi)

def change_sclk(dut, sclk: int):
    set_ui_in_bit(dut, 1, sclk)

def change_ss(dut, ss: int):
    set_ui_in_bit(dut, 2, ss)


async def spi_transfer_16(dut, tx_data):
    #SPI MODE 0
    #CPOL = 0
    #CPHA = 0
    #MSB first
    rx_data = 0
    for i in range(15, -1, -1):
        # Data valid before rising edge
        change_mosi(dut, ((tx_data >> i) & 0x1))
        
        # Half cycle
        await ClockCycles(dut.clk, 18)
        # Rising edge SCLK
        change_sclk(dut, 1) 
        # Sample MISO
        miso = int(dut.uo_out.value.binstr[-1])
        rx_data = (rx_data << 1) | miso
        # Half cycle
        await ClockCycles(dut.clk, 18)
        # Falling edge SCLK
        change_sclk(dut, 0) 
    return rx_data

############################################################
# Main test
############################################################

@cocotb.test()
async def test_project(dut):
    dut._log.info("Start")

    # Set the clock period to 20 ns (50 MHz)
    clock = Clock(dut.clk, 20, unit="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut._log.info("Reset")
    dut.ena.value = 1
    dut.rst_n.value = 0
    dut.ui_in.value = 4  #MOSI=0, SCLK=0, SS=1
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 10)

    ########################################################
    # SPI Frame: SUM with ACC=0.0
    ########################################################

    dut._log.info("SPI TEST: SUM ACC=0.0")

    change_ss(dut, 0)
    rx1 = await spi_transfer_16(dut, 0b0000_0000_0000_0000)
    rx2 = await spi_transfer_16(dut, 0x4040)  # 3.0
    rx3 = await spi_transfer_16(dut, 0x4000)  # 2.0
    rx4 = await spi_transfer_16(dut, 0x3DCC)  # 0.1
    rx5 = await spi_transfer_16(dut, 0x0000)  # dummy
    change_ss(dut, 1)
    
    assert rx1 == 0x0000, (f"ERROR rx1: expected=0x0000 received=0x{rx1:04X}")
    assert rx2 == 0x0000, (f"ERROR rx2: expected=0x0000 received=0x{rx2:04X}")
    assert rx3 == 0x4040, (f"ERROR rx3: expected=0x4040 received=0x{rx3:04X}")
    assert rx4 == 0x40A0, (f"ERROR rx4: expected=0x4000 received=0x{rx4:04X}")
    assert rx5 == 0x40A3, (f"ERROR rx5: expected=0x3DCC received=0x{rx5:04X}")
    
    await ClockCycles(dut.clk, 500)

    

    ########################################################
    # SPI Frame: SUB with ACC=1.0
    ########################################################
 
    dut._log.info("SPI TEST: SUB ACC=1.0")

    change_ss(dut, 0)
    rx1 = await spi_transfer_16(dut, 0b1000_0001_0000_0000)
    rx2 = await spi_transfer_16(dut, 0x4040)  # 3.0
    rx3 = await spi_transfer_16(dut, 0x4000)  # 2.0
    rx4 = await spi_transfer_16(dut, 0x3DCC)  # 0.1
    rx5 = await spi_transfer_16(dut, 0x0000)  # dummy
    change_ss(dut, 1)

    assert rx1 == 0x40A3, (f"ERROR rx1: expected=0x0000 received=0x{rx1:04X}")
    assert rx2 == 0x3F80, (f"ERROR rx2: expected=0x3F80 received=0x{rx2:04X}")
    assert rx3 == 0xC000, (f"ERROR rx3: expected=0xC000 received=0x{rx3:04X}")
    assert rx4 == 0xC080, (f"ERROR rx4: expected=0xC080 received=0x{rx4:04X}")
    assert rx5 == 0xC083, (f"ERROR rx5: expected=0xC083 received=0x{rx5:04X}")

    await ClockCycles(dut.clk, 500)

    ########################################################
    # SPI Frame: MPY with ACC=0.0
    ########################################################

    dut._log.info("SPI TEST: MPY ACC=0.0")

    change_ss(dut, 0)
    rx1 = await spi_transfer_16(dut, 0b0001_0000_0000_0000)
    rx2 = await spi_transfer_16(dut, 0x4040)  # 3.0
    rx3 = await spi_transfer_16(dut, 0x4000)  # 2.0
    rx4 = await spi_transfer_16(dut, 0x3DCC)  # 0.1
    rx5 = await spi_transfer_16(dut, 0x0000)  # dummy
    change_ss(dut, 1)

    assert rx1 == 0xC083, (f"ERROR rx1: expected=0x0000 received=0x{rx1:04X}")
    assert rx2 == 0x0000, (f"ERROR rx2: expected=0x0000 received=0x{rx2:04X}")
    assert rx3 == 0x0000, (f"ERROR rx3: expected=0x0000 received=0x{rx3:04X}")
    assert rx4 == 0x0000, (f"ERROR rx4: expected=0x0000 received=0x{rx4:04X}")
    assert rx5 == 0x0000, (f"ERROR rx5: expected=0x0000 received=0x{rx5:04X}")

    await ClockCycles(dut.clk, 500)

    ########################################################
    # SPI Frame: MPY with ACC=1.0
    ########################################################

    dut._log.info("SPI TEST: MPY ACC=1.0")

    change_ss(dut, 0)
    rx1 = await spi_transfer_16(dut, 0b0001_0001_0000_0000)
    rx2 = await spi_transfer_16(dut, 0x4040)  # 3.0
    rx3 = await spi_transfer_16(dut, 0x4000)  # 2.0
    rx4 = await spi_transfer_16(dut, 0x3DCC)  # 0.1
    rx5 = await spi_transfer_16(dut, 0x0000)  # dummy
    change_ss(dut, 1)

    await ClockCycles(dut.clk, 500)

    assert rx1 == 0x0000, (f"ERROR rx1: expected=0x0000 received=0x{rx1:04X}")
    assert rx2 == 0x3F80, (f"ERROR rx2: expected=0x3F80 received=0x{rx2:04X}")
    assert rx3 == 0x4040, (f"ERROR rx3: expected=0x4040 received=0x{rx3:04X}")
    assert rx4 == 0x40C0, (f"ERROR rx4: expected=0x40C0 received=0x{rx4:04X}")
    assert rx5 == 0x3F19, (f"ERROR rx5: expected=0x3F19 received=0x{rx5:04X}")


    ########################################################
    # SPI Frame: MAC with ACC=0.0
    ########################################################

    dut._log.info("SPI TEST: MAC ACC=0.0")

    change_ss(dut, 0)
    rx1 = await spi_transfer_16(dut, 0b0001_0000_0000_0000)
    rx2 = await spi_transfer_16(dut, 0x4040)  # 3.0
    rx3 = await spi_transfer_16(dut, 0x4000)  # 2.0
    rx4 = await spi_transfer_16(dut, 0x3DCC)  # 0.1
    rx5 = await spi_transfer_16(dut, 0xC000)  # -2.0
    rx6 = await spi_transfer_16(dut, 0x0000)  # 0.0
    change_ss(dut, 1)

    await ClockCycles(dut.clk, 500)
    
    assert rx1 == 0x0000, (f"ERROR rx1: expected=0x0000 received=0x{rx1:04X}")
    assert rx2 == 0x0000, (f"ERROR rx2: expected=0x0000 received=0x{rx2:04X}")
    assert rx3 == 0x0000, (f"ERROR rx3: expected=0x0000 received=0x{rx3:04X}")
    assert rx4 == 0x40C0, (f"ERROR rx4: expected=0x40C0 received=0x{rx4:04X}")
    assert rx5 == 0x40C0, (f"ERROR rx5: expected=0x40C0 received=0x{rx5:04X}")
    assert rx6 == 0x40BA, (f"ERROR rx6: expected=0x40BA received=0x{rx6:04X}")

    dut._log.info("All SPI tests completed")

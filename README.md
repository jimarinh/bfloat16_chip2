![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg) ![](../../workflows/test/badge.svg) ![](../../workflows/fpga/badge.svg)

# SPI bfloat16 accelerator for TinyTapeout tile

- [Read the documentation for project](docs/info.md)

## What is this?

This project is a hardware accelerator for neuronal computations using bfloat16 numbers. 
Supported operations include addition/subtraction, multiplication which are performed on an accumulator to support sequential operations such as continuous summations and products. It has been designed for a TinyTapeout tile.

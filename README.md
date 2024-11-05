# Histogram Equalization for Image Contrast Enhancement

## Overview

This project implements histogram equalization for enhancing the contrast of a grayscale image using VHDL on an FPGA development system. The task includes processing an image stored in multiple BRAMs, calculating a histogram, performing cumulative histogram equalization, and transmitting the processed image to a PC via UART.

## Features

- **Memory for Image Storage**: 
  - Image stored across 8 parallel BRAMs, each handling a portion of the image data.
  - Simple Dual Port BRAM implementation allows simultaneous reading and writing.
- **Histogram Calculation**:
  - Calculation of a simple histogram by counting pixel intensities (0–255).
  - Summing and storing histogram data for parallel BRAM modules.
- **Cumulative Histogram**:
  - Generation of cumulative histogram and application of a transformation function to equalize pixel intensities.
  - Writing the transformed pixel values back into the same BRAMs.
- **Image Transmission to PC**:
  - A UART transmitter is used to send the equalized image data from the FPGA to the PC.
  - Button-triggered data transfer with support for flow control.

## Project Files

- **im_ram.vhd**: Defines the BRAM memory structure for storing image data. Each memory block stores 1/8 of the image.
- **histogram_calc.vhd**: Module responsible for calculating the histogram of pixel intensities for each BRAM block.
- **cumulative_histogram.vhd**: Module that computes the cumulative histogram and performs pixel intensity equalization.
- **uart_tx.vhd**: UART transmitter module for sending pixel data to a PC.
- **main_controller.vhd**: The main control unit that coordinates memory read/write operations, histogram calculation, and UART data transmission.

## Data Files

- **lenaCorrupted0.dat to lenaCorrupted7.dat**: Data initialization files that store the image data for BRAM loading.
- **equalized_image.txt**: Output file containing pixel data after histogram equalization.

## Usage

1. **Compile and Synthesize**: Use your preferred VHDL toolchain (e.g., Xilinx Vivado) to compile and synthesize the project.
2. **Program FPGA**: Load the synthesized design onto the FPGA development board.
3. **Run the Simulation**: Execute the design on the FPGA, ensuring that the image is correctly equalized and transmitted via UART.
4. **Compare Results**: Verify the output by comparing the `equalized_image.txt` file with the provided Python script output for histogram equalization.

## Dependencies

- **FPGA Development Board**: Ensure compatibility with the target board (e.g., Xilinx Artix-7).
- **UART Driver**: Install the Prolific PL2303 driver for UART communication on Windows. Linux users can access UART without additional drivers.

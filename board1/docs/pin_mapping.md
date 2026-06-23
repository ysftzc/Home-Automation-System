# Pin Mapping – Board #1  
## Home Air Conditioner System

**Author:** Yusuf Tuzcu  
**Student ID:** 151220202144  
**Course:** Introduction to Microcomputers  
**Semester:** Fall 2025

---

## 1. Overview

This document describes the **pin mapping configuration for Board #1** of the Home Air Conditioner System.  
Board #1 is responsible for temperature sensing, user interaction, actuator control, display management, and serial communication.  
All pin assignments are defined to ensure consistency between hardware connections and software modules.

---

## 2. Temperature System Pin Mapping

The temperature system includes the LM35 temperature sensor, heater, fan (cooler), and tachometer input.

| Function | PIC Pin | Direction | Description |
|--------|---------|-----------|-------------|
| LM35 Temperature Sensor | RA0 / AN0 | Input | Analog ambient temperature input |
| Heater Control | RB0 | Output | Heater ON/OFF digital control |
| Cooler (Fan) Control | RB1 | Output | Fan ON/OFF digital control |
| Tachometer Pulse | RA4 / T0CKI | Input | Fan speed pulses counted by Timer0 |

---

## 3. Keypad (4×4 Matrix) Pin Mapping

A 4×4 matrix keypad is used to enter the desired temperature.

| Signal Type | PIC Pins | Direction | Description |
|------------|----------|-----------|-------------|
| Row Lines | RD0–RD3 | Input | Keypad row input signals |
| Column Lines | RD4–RD7 | Output | Keypad column driving signals |

---

## 4. Seven-Segment Display Pin Mapping

A four-digit multiplexed seven-segment display is used for system feedback.

### 4.1 Segment Control Lines

| Segment | PIC Pin | Direction | Description |
|--------|---------|-----------|-------------|
| a | RB2 | Output | Segment a |
| b | RB3 | Output | Segment b |
| c | RB4 | Output | Segment c |
| d | RB5 | Output | Segment d |
| e | RB6 | Output | Segment e |
| f | RB7 | Output | Segment f |
| g | RC0 | Output | Middle segment |
| dp | RC1 | Output | Decimal point |

### 4.2 Digit Select Lines

| Digit | PIC Pin | Direction | Description |
|------|---------|-----------|-------------|
| D1 (LSB) | RC2 | Output | Least significant digit |
| D2 | RC3 | Output | Digit 2 |
| D3 | RC4 | Output | Digit 3 |
| D4 (MSB) | RC5 | Output | Most significant digit |

---

## 5. UART Pin Mapping

UART is used for communication with a PC and with Board #2.

| Signal | PIC Pin | Direction | Description |
|-------|---------|-----------|-------------|
| TX | RC6 | Output | Serial data transmission |
| RX | RC7 | Input | Serial data reception |

---

## 6. Notes and Assumptions

| Item | Description |
|----|-------------|
| ADC Reference | VDD–VSS (0–5 V) |
| Timer0 Mode | External clock via RA4 / T0CKI |
| UART Format | 8 data bits, no parity, 1 stop bit (8N1) |
| Design Scope | Board #1 temperature control subsystem |

---

## 7. Consistency with Software Modules

All pin assignments defined in this document are consistently used across the following software modules:

| Module | Related Pins |
|------|--------------|
| `adc.asm` | RA0 / AN0 |
| `keypad.asm` | RD0–RD7 |
| `tach.asm` | RA4 / T0CKI |
| `seg7.asm` | RB2–RB7, RC0–RC5 |
| `uart.asm` | RC6, RC7 |
| `main.asm` | Global configuration and control |

---

This pin mapping serves as the single reference for both hardware connections and software configuration of Board #1.

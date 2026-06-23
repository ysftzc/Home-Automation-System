# PIN Mapping – Home Automation System
This document defines the PIC16F877A pin connections for both boards as required by **R2_1** in the term project specifications.

All Assembly code, PICSimLab connections, and UART communication routines must follow this mapping.

---

# 🟦 Board #1 – Air Conditioner System (PIC16F877A)

## 1. Temperature System

| Function                     | PIC Pin     | Direction | Notes                                    |
|-----------------------------|-------------|-----------|------------------------------------------|
| LM35 Temperature Sensor     | RA0 / AN0   | Input     | Ambient temperature analog input         |
| Heater Control              | RB0         | Output    | Digital output: Heater ON/OFF            |
| Cooler (Fan) Control        | RB1         | Output    | Digital output: Cooler/Fan ON/OFF        |
| Tachometer Pulse            | RA4 / T0CKI | Input     | Fan rps via Timer0 external clock        |

---

## 2. Keypad (4×4 Matrix)

| Keypad Line | PIC Pin | Direction | Description |
|-------------|---------|-----------|-------------|
| R1          | RD0     | Input     | Row 1       |
| R2          | RD1     | Input     | Row 2       |
| R3          | RD2     | Input     | Row 3       |
| R4          | RD3     | Input     | Row 4       |
| C1          | RD4     | Output    | Column 1    |
| C2          | RD5     | Output    | Column 2    |
| C3          | RD6     | Output    | Column 3    |
| C4          | RD7     | Output    | Column 4    |

---

## 3. 7-Segment Display (4-Digit Multiplexed)

### Segment Lines

| Segment | PIC Pin | Direction |
|---------|---------|-----------|
| a       | RB2     | Output    |
| b       | RB3     | Output    |
| c       | RB4     | Output    |
| d       | RB5     | Output    |
| e       | RB6     | Output    |
| f       | RB7     | Output    |
| g       | RC0     | Output    |
| dp      | RC1     | Output    |

### Digit Select Lines

| Digit | PIC Pin | Direction | Notes                     |
|-------|---------|-----------|---------------------------|
| D1    | RC2     | Output    | Least significant digit   |
| D2    | RC3     | Output    |                           |
| D3    | RC4     | Output    |                           |
| D4    | RC5     | Output    | Most significant digit    |

---

## 4. UART (Hardware Serial)

| UART Signal | PIC Pin | Direction | Notes              |
|-------------|---------|-----------|--------------------|
| TX          | RC6     | Output    | PIC → PC           |
| RX          | RC7     | Input     | PC → PIC           |

---

# 🟩 Board #2 – Curtain Control System (PIC16F877A)

## 1. Step Motor (4-Coil)

| Coil | PIC Pin | Direction |
|------|---------|-----------|
| IN1  | RB0     | Output    |
| IN2  | RB1     | Output    |
| IN3  | RB2     | Output    |
| IN4  | RB3     | Output    |

---

## 2. LDR Light Sensor

| Signal          | PIC Pin   | Direction | Notes                                             |
|-----------------|-----------|-----------|---------------------------------------------------|
| Analog Output   | RA0 / AN0 | Input     | Light intensity analog value                      |
| Digital Output  | RD0       | Input     | Comparator output (light below/above threshold)   |

---

## 3. BMP180 (I²C Sensor)

| BMP180 Pin | PIC Pin   | Direction | Notes                |
|------------|-----------|-----------|----------------------|
| SDA        | RC4 / SDA | In/Out    | I²C Data            |
| SCL        | RC3 / SCL | Output    | I²C Clock           |

---

## 4. Rotary Potentiometer

| Signal       | PIC Pin   | Direction | Notes                                 |
|--------------|-----------|-----------|---------------------------------------|
| Analog Out   | RA2 / AN2 | Input     | Maps 0–5V to curtain percentage (0–100%) |

---

## 5. LCD (hd44780 – 4-Bit Mode)

| LCD Pin | PIC Pin | Direction | Notes             |
|---------|---------|-----------|-------------------|
| RS      | RE0     | Output    | Register Select   |
| E       | RE1     | Output    | Enable            |
| D4      | RD4     | Output    | Data bit 4        |
| D5      | RD5     | Output    | Data bit 5        |
| D6      | RD6     | Output    | Data bit 6        |
| D7      | RD7     | Output    | Data bit 7        |
| R/W     | GND     | -         | Always write mode |

---

## 6. UART (Hardware Serial)

| UART Signal | PIC Pin | Direction |
|-------------|---------|-----------|
| TX          | RC6     | Output    |
| RX          | RC7     | Input     |

---

# ✔ Notes
- TRIS registers must be configured according to table directions.  
- PICSimLab pin assignments must exactly match this file.  
- UART communication: **9600 baud, 8N1**.  
- Changing any pin requires updating *all* Assembly code and this file.


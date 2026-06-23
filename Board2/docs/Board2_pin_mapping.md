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

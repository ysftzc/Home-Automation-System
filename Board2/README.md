# Board #2 – Smart Curtain Control System

## Environmental Sensing and Actuation Unit

\---

This directory contains the complete implementation of **Board #2** for the *Home Automation System* term project.  
Board #2 functions as the **environment-aware actuation unit**, responsible for light sensing, outdoor environmental monitoring and curtain motor control.

The system is implemented on the **PIC16F877A microcontroller** using **assembly language**, following a **modular and task-oriented software architecture**.

\---

## 1\. System Purpose and Functionality

Board #2 controls an automated curtain system based on environmental conditions and commands received from PC application.  
It monitors ambient light level and outdoor weather parameters, determines curtain position, and drives a stepper motor accordingly.

### Core Functions

|Function|Description|
|-|-|
|Ambient Light Measurement|Reads LDR sensor via ADC|
|Outdoor Environment Sensing|Temperature and pressure measurement via BMP180 (I2C)|
|Curtain Position Control|Stepper motor driving (open / close / stop)|
|Decision Support|Local threshold-based logic|
|Communication|UART-based data exchange with PC/Board #1|
|System Feedback|Status data transmission over UART|

\---

## 2\. Hardware Configuration

### 2.1 Light Sensor (LDR) Pin Mapping

|Function|PIC Pin|Direction|Description|
|-|-|-|-|
|LDR Sensor|RA0 / AN0|Input|Analog ambient light input|

\---

### 2.2 Rotational Potentiometer Pin Mapping

|Function|PIC Pin|Direction|Description|
|-|-|-|-|
|Rotational Potentiometer|RA2 / AN2|Input|Curtain Position input|

\---

### 2.3 Stepper Motor Driver Pin Mapping

|Coil|PIC Pin|Direction|Description|
|-|-|-|-|
|Coil A|RB0|Output|Stepper motor phase A|
|Coil B|RB1|Output|Stepper motor phase B|
|Coil C|RB2|Output|Stepper motor phase C|
|Coil D|RB3|Output|Stepper motor phase D|

\---

### 2.4 I2C Interface (BMP180 Sensor)

|Signal|PIC Pin|Direction|Description|
|-|-|-|-|
|SDA|RC4|I/O|I2C data line|
|SCL|RC3|Output|I2C clock line|

\---

### 2.5 UART Interface

|Signal|PIC Pin|Direction|Description|
|-|-|-|-|
|TX|RC6|Output|Serial transmission|
|RX|RC7|Input|Serial reception|

\---

### 2.6 LCD (hd44780 – 4-Bit Mode)

|LCD Pin|PIC Pin|Direction|Notes|
|-|-|-|-|
|RS|RE0|Output|Register Select|
|E|RE1|Output|Enable|
|D4|RD4|Output|Data bit 4|
|D5|RD5|Output|Data bit 5|
|D6|RD6|Output|Data bit 6|
|D7|RD7|Output|Data bit 7|
|R/W|GND|-|Always write mode|

## 3\. Software Architecture

The firmware is organized into **independent functional modules**, each responsible for a specific subsystem.  
All modules communicate through **shared RAM variables**, ensuring deterministic execution and minimal coupling.

### Software Modules

|File|Description|
|-|-|
|`main.asm`|System initialization and main control loop|
|`adc.asm`|LDR light level acquisition/Curtain Control Position|
|`stepper.asm`|Stepper motor control and sequencing|
|`i2c.asm`|I2C master driver|
|`bmp180.asm`|Outdoor temperature and pressure acquisition|
|`uart.asm`|UART communication with PC/Board #1|

\---

## 4\. Main Loop Execution Model

After system initialization, Board #2 operates in a continuous loop executing all tasks sequentially.

### Task Execution Order

|Step|Task|Purpose|
|-|-|-|
|1|ADC Task|Sample ambient light level|
|2|BMP180 Task|Read outdoor temperature and pressure|
|3|Decision Task|Determine curtain action|
|4|Stepper Task|Drive curtain motor|
|5|UART Task|Exchange data with Board #1|

This cooperative scheduling model ensures predictable timing without interrupts.

\---

## 5\. Data Representation

To simplify computation and avoid floating-point arithmetic, all sensor data is represented in integer or fixed-point format.

|Parameter|Format|Example|
|-|-|-|
|Light Level|8-bit ADC|0–255|
|Pressure|Integer (hPa)|1025|

\---

## 6\. System Assumptions and Notes

|Item|Description|
|-|-|
|ADC Resolution|10-bit (left-justified)|
|I2C Speed|100 kHz (Standard Mode)|
|UART Format|8 data bits, no parity, 1 stop bit (8N1)|
|Motor Type|4-phase unipolar stepper motor|
|Design Goal|Autonomous operation with PC/Board #1 integration|

\---

## 7\. Documentation

Detailed design explanations, timing diagrams, flowcharts, and experimental results are provided in the **Board #2 Report** submitted with the project.

\---




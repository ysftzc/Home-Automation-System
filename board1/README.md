# Board #1 – Home Air Conditioner System

## Temperature Control and User Interface Unit

\---



This directory contains the complete implementation of **Board #1** for the *Home Air Conditioner System* term project.  
Board #1 acts as the **primary sensing, control, and user-interaction unit**, responsible for temperature measurement, control decision-making, actuator driving, and real-time feedback.

The system is implemented on the **PIC16F877A microcontroller** using **assembly language** and follows a **modular, task-based software architecture**.

\---

## 1\. System Purpose and Functionality

Board #1 realizes a closed-loop temperature control system. During operation, it continuously monitors ambient temperature, accepts user-defined desired temperature input, controls heater and fan outputs accordingly, and provides system feedback via display and UART communication.

### Core Functions

|Function|Description|
|-|-|
|Ambient Temperature Measurement|Reads LM35 sensor via ADC (AN0)|
|Desired Temperature Input|User input through 4×4 matrix keypad|
|Temperature Control|Heater/Fan control based on temperature comparison|
|Fan Speed Measurement|Tachometer pulse counting using Timer0|
|Visual Feedback|4-digit multiplexed seven-segment display|
|Communication|UART-based data exchange with PC / Board #2|

\---

## 2\. Hardware Configuration

### 2.1 Temperature System Pin Mapping

|Function|PIC Pin|Direction|Description|
|-|-|-|-|
|LM35 Temperature Sensor|RA0 / AN0|Input|Analog ambient temperature input|
|Heater Control|RB0|Output|Heater ON/OFF control|
|Cooler (Fan) Control|RB1|Output|Fan ON/OFF control|
|Tachometer Pulse|RA4 / T0CKI|Input|Fan speed pulses (Timer0 clock)|

\---

### 2.2 Keypad (4×4 Matrix) Pin Mapping

|Signal Type|PIC Pins|Direction|Description|
|-|-|-|-|
|Row Lines|RD0–RD3|Input|Keypad row inputs|
|Column Lines|RD4–RD7|Output|Keypad column driving signals|

\---

### 2.3 Seven-Segment Display Pin Mapping

|Component|PIC Pins|Direction|Description|
|-|-|-|-|
|Segments a–f|RB2–RB7|Output|Segment control lines|
|Segment g|RC0|Output|Middle segment|
|Decimal Point (dp)|RC1|Output|Decimal point control|
|Digit Select (D1–D4)|RC2–RC5|Output|Digit multiplexing|

\---

### 2.4 UART Interface

|Signal|PIC Pin|Direction|Description|
|-|-|-|-|
|TX|RC6|Output|Serial transmission|
|RX|RC7|Input|Serial reception|

\---

## 3\. Software Architecture

The software is structured into **independent functional modules**, each implemented as a task.  
Modules interact exclusively via **shared memory variables**, ensuring low coupling and high modularity.

### Software Modules

|File|Description|
|-|-|
|`main.asm`|System initialization and main loop scheduler|
|`adc.asm`|Ambient temperature acquisition and scaling|
|`keypad.asm`|Desired temperature input and validation|
|`tach.asm`|Fan speed measurement (rps)|
|`seg7.asm`|Seven-segment display multiplexing and mode control|
|`uart.asm`|UART communication with PC / Board #2|

\---

## 4\. Main Loop Execution Model

After initialization, the system enters an infinite loop where all tasks are executed sequentially in a deterministic order.

### Task Execution Order

|Step|Task|Purpose|
|-|-|-|
|1|Keypad Task|Read and update desired temperature|
|2|ADC Task|Sample ambient temperature|
|3|Tachometer Task|Measure fan speed|
|4|Control Task|Update heater and fan outputs|
|5|Display Task|Refresh display and switch modes|
|6|UART Task|Handle serial communication|

This approach guarantees continuous system responsiveness without blocking delays.

\---

## 5\. Data Representation

To ensure efficient computation without floating-point arithmetic, fixed-point representation is used.

|Parameter|Format|Example|
|-|-|-|
|Temperature|×10 fixed-point|24.5°C → 245|
|Fan Speed|Integer (rps)|3 rps|

\---

## 6\. System Assumptions and Notes

|Item|Description|
|-|-|
|ADC Reference|VDD–VSS (0–5 V)|
|UART Format|8 data bits, no parity, 1 stop bit (8N1)|
|Timer0 Mode|External clock via RA4/T0CKI|
|Design Goal|Modular, scalable, Board #2 compatible|

\---

## 7\. Documentation

Detailed explanations, flowcharts, system analysis, and experimental results are provided in the **Board #1 Report** submitted with the project.

\---

**Author:** Yusuf Tuzcu  
**Course:** Introduction to Microcomputers  
**Semester:** Fall 2025


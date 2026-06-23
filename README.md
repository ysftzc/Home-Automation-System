
## 📖 Project Abstract

This project aims to develop a comprehensive **Home Automation System** that controls various home sensors and drivers using **PIC16F877A** microcontrollers and allows users to manage the system via a **PC interface**

The system consists of two main parts

1. **Firmware:** Assembly code running on two separate PIC16F877A microcontrollers to manage peripherals (sensors, displays, motors).
2. **Software:** A PC application (API + User Interface) developed in \[Python/C++/Java] that communicates with the microcontrollers via **UART** serial interface.

## 🏗 Hardware Architecture \& Features

The project is simulated using **PICSimLab** with the `gpboard` board.

\###Board #1: Air Conditioner System
This board manages the home air conditioning system.

* **Temperature Control:** Controls Heater, Cooler, and Fan based on desired vs. ambient temperature.
* **User Input:** 4x3 or 4x4 Keypad for entering desired temperature values.
* **Display:** 7-Segment Display to show desired temp, ambient temp, and fan speed.
* **Communication:** UART interface for PC commands.

### Board #2: Curtain Control System

This board manages the curtain automation and environmental monitoring.

* **Curtain Motor:** Stepper Motor control for opening/closing curtains (0% - 100%).
* **Light Sensor:** LDR sensor to automatically close curtains when light intensity is low.
* **Environmental Sensor:** BMP180 sensor for reading outdoor temperature and pressure.
* **Manual Control:** Rotary Potentiometer for manual curtain adjustment.
* **Display:** LCD (hd44780) to display outdoor data and curtain status.

## 💻 Software Architecture

### PC API \& Application

* **API:** A robust library (class-based) handling serial communication (opening/closing ports, sending/receiving data packets).
* **User Interface:** A menu-based application allowing users to view sensor data and set control parameters (e.g., Set Desired Temp, Set Curtain Status).

### Communication Protocol

Data is exchanged via UART (9600 baud rate, 8N1 format) using a specific binary command set defined in the project requirements.

## 🛠 Tools Required

* **Simulator:** PICSimLab (v0.9.2 or later).
* **Serial Emulator:** com0com, tty0tty, or similar virtual serial port software.
* **IDE (PIC):** MPLAB X or similar for Assembly development.
* **IDE (PC):** VS Code, PyCharm, or similar for PC application development.

## 🚀 How to Run

1. Open `Board1.pzw` and `Board2.pzw` in **PICSimLab**.
2. Set up the virtual serial ports (e.g., COM1 <-> COM2, COM3 <-> COM4).
3. Load the compiled `.hex` files into the respective PIC microcontrollers.
4. Run the PC Application script.
5. Use the console menu to interact with the simulation.
6. 


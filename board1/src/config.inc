; =========================================================
; config.inc (PIN MAPPING v2 - RECOMMENDED)  - Board #1
; Author      : Yusuf Tuzcu
; Student ID  : 151220202144
; Department  : Electrical and Electronics Engineering
; =========================================================
; Overview:
;   Project-wide configuration header for PIC16F877A.
;   This file centralizes:
;     - MCU configuration bits (oscillator, WDT, BOR, LVP, protections)
;     - shared STATUS/interrupt bit aliases
;     - hardware pin mapping for: LM35 (ADC), heater/cooler outputs,
;       keypad scan lines, 7-segment digit enables, UART pins, optional tach input
;     - common key codes and temperature-control constants (hysteresis)
;
; Functional Traceability:
;   [R2.1.1] Temperature controller definitions (heater/cooler pins + hysteresis)
;   [R2.1.2] Keypad scan / key codes (A, *, #, none)
;   [R2.1.3] 7-segment multiplexing (digit enable bits)
;   [R2.1.4] UART interface mapping (RC6 TX / RC7 RX)
; =========================================================

    PROCESSOR   16F877A
    #include    <xc.inc>

; -----------------------------
; CONFIG BITS (Device Configuration Words)
; -----------------------------
; FOSC = XT   : External crystal/resonator (e.g., 4 MHz) for stable timing base.
; WDTE = OFF  : Watchdog disabled for deterministic lab execution.
; PWRTE = ON  : Power-up timer enabled (supply stabilization).
; BOREN = ON  : Brown-out reset enabled (low-voltage robustness).
; LVP  = OFF  : Low-voltage programming disabled (RB3 usable as normal I/O).
; CP/CPD/WRT  : Protections disabled for development/debug convenience.
    CONFIG  FOSC = XT
    CONFIG  WDTE = OFF
    CONFIG  PWRTE = ON
    CONFIG  BOREN = ON
    CONFIG  LVP  = OFF
    CONFIG  CPD  = OFF
    CONFIG  WRT  = OFF
    CONFIG  CP   = OFF


; -----------------------------
; Common STATUS bits
; -----------------------------
; Symbolic aliases to avoid hard-coded bit numbers across modules.
C_BIT           EQU 0          ; STATUS<0> Carry flag
Z_BIT           EQU 2          ; STATUS<2> Zero flag


; -----------------------------
; ADC control bits
; -----------------------------
; Used by ADC routines when starting/polling conversions.
GO_BIT          EQU 2          ; ADCON0<2> GO/DONE


; -----------------------------
; Interrupt control bits
; -----------------------------
; Common symbols used by ISR setup and flag handling.
INTF_BIT        EQU 1          ; INTCON<1> External interrupt flag
INTE_BIT        EQU 4          ; INTCON<4> External interrupt enable
GIE_BIT         EQU 7          ; INTCON<7> Global interrupt enable


; -----------------------------
; Outputs (PORTA) - Temperature Control
; -----------------------------
; Heater/Cooler drive pins controlled by temperature logic.
; LM35 sensor input is RA0/AN0 (ADC module handles analog setup).
HEATER_PORT     EQU PORTA
HEATER_TRIS     EQU TRISA
HEATER_BIT      EQU 1          ; RA1 -> heater control output

COOLER_PORT     EQU PORTA
COOLER_TRIS     EQU TRISA
COOLER_BIT      EQU 2          ; RA2 -> cooler/fan control output

; Optional tachometer input (if speed measurement is enabled)
TACH_BIT        EQU 4          ; RA4/T0CKI (Timer0 external clock input)


; -----------------------------
; 7-seg digit selects (PORTC) - Multiplex Control
; -----------------------------
; Digit enable signals (active HIGH). Segment lines are on PORTD.
DIG1_BIT        EQU 2          ; RC2 (least significant digit)
DIG2_BIT        EQU 3          ; RC3
DIG3_BIT        EQU 4          ; RC4
DIG4_BIT        EQU 5          ; RC5 (most significant digit)


; -----------------------------
; Display modes (high-level UI states)
; -----------------------------
; Values used by seg7/display task to select which quantity is shown.
DISP_DESIRED    EQU 0          ; show desired temperature
DISP_AMBIENT    EQU 1          ; show ambient temperature
DISP_FAN        EQU 2          ; show fan status/speed (RPM/indicator)


; -----------------------------
; Key codes (4x4 keypad)
; -----------------------------
; Returned by keypad scan routine.
; KP_KEY_NONE is returned when no key is pressed.
KP_KEY_NONE     EQU 0xFF
KP_KEY_A        EQU 10         ; A key (start entry / mode trigger per logic)
KP_KEY_STAR     EQU 14         ; '*' key (fraction / special function)
KP_KEY_HASH     EQU 15         ; '#' key (commit/confirm)


; -----------------------------
; Control constants
; -----------------------------
; Hysteresis band for temperature control in x10 format (°C * 10).
; Example: HYST_X10=5 -> 0.5°C hysteresis.
HYST_X10        EQU 5          ; 0.5°C hysteresis (x10 format)

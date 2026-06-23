﻿; =========================================================
; main.asm (PIN MAPPING v2)  - Board #1
; Author      : Yusuf Tuzcu
; Student ID  : 151220202144
; Department  : Electrical and Electronics Engineering
; =========================================================
; Target MCU  : PIC16F877A (XC8 pic-as)
; Description :
;   Top-level application entry for the Board1 temperature control system.
;   Integrates the following modules:
;     - adc.asm   : reads LM35 temperature on RA0/AN0
;     - keypad.asm: 4x4 keypad input (A ... #) to set desired temperature
;     - seg7.asm  : 4-digit 7-seg multiplex display (DES -> AMB -> RPM)
;     - uart.asm  : optional serial status streaming (TX=RC6, RX=RC7)
;     - tach.asm  : fan speed measurement using RA4/T0CKI + Timer1 gate
;
; Hardware mapping (PIN MAPPING v2):
;   Temperature:
;     LM35   : RA0/AN0 (ADC)
;     HEATER : RA1
;     COOLER : RA2
;     TACH   : RA4/T0CKI (Timer0 external clock input)
;
;   Keypad (4x4):
;     Rows : RB0..RB3 inputs (PORTB pull-ups enabled)
;     Cols : RB4..RB7 outputs (scan one column low at a time)
;
;   7-Segment (4-digit multiplex):
;     Segments : PORTD RD0..RD7 (a..g,dp)
;     Digits   : PORTC RC2..RC5 (DIG1..DIG4) active HIGH
;
;   UART:
;     TX : RC6
;     RX : RC7
;
; Functional summary:
;   - Reads ambient temperature from LM35 (0.1°C format)
;   - Accepts desired setpoint via keypad (10.0°C .. 50.0°C)
;   - Applies hysteresis control to drive HEATER/COOLER outputs
;   - Displays DES/AMB/RPM in a rotating 3-mode view
;   - Optionally streams status via UART
;
; Requirement Mapping:
;   [R2.1.1-1] System shall read ambient temperature using ADC (LM35 on AN0).
;   [R2.1.2-1] User shall enter desired temperature using keypad (A...# commit).
;   [R2.1.3-1] System shall display DES, AMB, and FAN speed on 7-seg.
;   [R2.1.4-1] System may transmit status via UART (optional feature).
;   [R2.1.5-1] System shall control HEATER/COOLER using hysteresis logic.
; =========================================================

    PROCESSOR   16F877A
    #include    <xc.inc>
    #include    "config.inc"

; ---------------------------------------------------------
; RAM Allocation (BANK0)
; ---------------------------------------------------------
    PSECT   udata_bank0

; Tach measurement (shared with tach.asm)
TACH_GATE_L:    ds 1
TACH_GATE_H:    ds 1
TACH_COUNT:     ds 1

; Optional scratch bytes (x10 format helpers / thresholds)
AMB_X10:        ds 1
DES_X10:        ds 1
TH_HIGH:        ds 1
TH_LOW:         ds 1

; Desired temperature setpoint (integer + 1 fractional digit)
; Example: 45.0°C -> DES_TEMP_H=45, DES_TEMP_L=0
DES_TEMP_H:     ds 1
DES_TEMP_L:     ds 1

; Ambient temperature reading (integer + 1 fractional digit)
AMB_TEMP_H:     ds 1
AMB_TEMP_L:     ds 1

; Fan speed value used by display (scaled, e.g., RPM/10)
FAN_SPEED:      ds 1

; Keypad state machine variables (shared with keypad.asm)
KEY_STATE:      ds 1
KEY_BUFFER0:    ds 1
KEY_BUFFER1:    ds 1
KEY_BUFFER2:    ds 1
KEY_FLAGS:      ds 1

; Display mode control (shared with seg7.asm)
DISP_MODE:      ds 1
DISP_TIMER_L:   ds 1
DISP_TIMER_H:   ds 1

; ADC and general scratch variables
ADC_VALUE_H:    ds 1
ADC_VALUE_L:    ds 1
TEMP_RAW:       ds 1
TEMP_WORK:      ds 1

; Optional interrupt flag for RB0/INT keypad wake-up style operation
KP_INT_FLAG:    ds 1

    ; Export commonly used globals for included modules
    GLOBAL  DES_TEMP_H, DES_TEMP_L
    GLOBAL  AMB_TEMP_H, AMB_TEMP_L
    GLOBAL  FAN_SPEED
    GLOBAL  DISP_MODE, DISP_TIMER_L, DISP_TIMER_H

; ---------------------------------------------------------
; Reset and Interrupt Vectors
; ---------------------------------------------------------
    PSECT   resetVector,class=CODE,delta=2
    ORG     0x0000
    GOTO    INIT

    PSECT   intVector,class=CODE,delta=2
    ORG     0x0004
    GOTO    ISR

; ---------------------------------------------------------
; Program Code
; ---------------------------------------------------------
    PSECT   code,class=CODE,delta=2

; =========================================================
; INIT
; - Configures TRIS registers for all ports
; - Configures OPTION_REG for PORTB pull-ups and Timer0 external clock
; - Initializes port outputs and RAM variables
; - Calls module initialization routines
; - Enables optional RB0/INT interrupt for keypad flagging
; =========================================================
INIT:
; -----------------------------
; I/O Direction Configuration (TRIS)
; -----------------------------
    ; PORTA direction:
    ;   RA0 input  (AN0 / LM35 ADC)
    ;   RA1 output (HEATER)
    ;   RA2 output (COOLER / FAN)
    ;   RA4 input  (T0CKI / tach pulses)
    ; TRISA bit=1 input, bit=0 output -> 0b00010001
    banksel TRISA
    movlw   0b00010001
    movwf   TRISA

    ; PORTB keypad:
    ;   RB0..RB3 inputs  (rows)
    ;   RB4..RB7 outputs (columns)
    banksel TRISB
    movlw   0b00001111
    movwf   TRISB

    ; PORTC:
    ;   RC2..RC5 outputs (digit enables)
    ;   RC6 output (UART TX)
    ;   RC7 input  (UART RX)
    ; RC0/RC1 unused -> keep as outputs
    banksel TRISC
    movlw   0b10000000
    movwf   TRISC

    ; PORTD: 7-seg segments are outputs
    banksel TRISD
    clrf    TRISD

    ; PORTE unused -> outputs
    banksel TRISE
    clrf    TRISE

; -----------------------------
; OPTION_REG configuration
; -----------------------------
    ; OPTION_REG:
    ;   bit7 RBPU   = 0 -> enable PORTB pull-ups (required for keypad rows)
    ;   bit6 INTEDG = 0 -> INT on falling edge (RB0/INT), optional
    ;   bit5 T0CS   = 1 -> Timer0 clock source = external pin RA4/T0CKI (tach)
    ;   bit4 T0SE   = 0 -> increment on low-to-high transition
    ;   bit3 PSA    = 1 -> prescaler not assigned to Timer0
    banksel OPTION_REG
    bcf     OPTION_REG, 7
    bcf     OPTION_REG, 6
    bsf     OPTION_REG, 5
    bcf     OPTION_REG, 4
    bsf     OPTION_REG, 3

; -----------------------------
; Initial Output States
; -----------------------------
    ; PORTA requirement: avoid writing the whole PORTA with movwf/clrf
    ; because RA0 is analog input; use bit operations for outputs only.
    banksel PORTA
    bcf     PORTA, HEATER_BIT   ; HEATER OFF
    bcf     PORTA, COOLER_BIT   ; COOLER OFF

    ; PORTB:
    ;   - clear outputs
    ;   - set columns (RB4..RB7) to idle HIGH for keypad scanning
    banksel PORTB
    clrf    PORTB
    movlw   0b11110000
    iorwf   PORTB, F

    ; Clear PORTC/PORTD/PORTE outputs
    banksel PORTC
    clrf    PORTC
    banksel PORTD
    clrf    PORTD
    banksel PORTE
    clrf    PORTE

; -----------------------------
; Variable Initialization
; -----------------------------
    ; Default desired temperature = 45.0°C
    banksel DES_TEMP_H
    movlw   45
    movwf   DES_TEMP_H
    clrf    DES_TEMP_L

    ; Start ambient and fan values at 0 until first measurements
    clrf    AMB_TEMP_H
    clrf    AMB_TEMP_L
    clrf    FAN_SPEED

    ; Keypad state machine reset
    clrf    KEY_STATE
    movlw   0xFF
    movwf   KEY_BUFFER0
    movwf   KEY_BUFFER1
    movwf   KEY_BUFFER2
    clrf    KEY_FLAGS

    ; Display mode and timing reset
    clrf    DISP_MODE
    clrf    DISP_TIMER_L
    clrf    DISP_TIMER_H

    ; Scratch variables reset
    clrf    ADC_VALUE_H
    clrf    ADC_VALUE_L
    clrf    TEMP_RAW
    clrf    TEMP_WORK

    ; Optional interrupt flag reset
    clrf    KP_INT_FLAG

; -----------------------------
; Module Initialization Calls
; -----------------------------
    call    ADC_INIT
    call    KEYPAD_INIT
    call    SEG7_INIT
    call    UART_INIT
    call    TACH_INIT

; -----------------------------
; Optional External Interrupt Enable (RB0/INT)
; - Used only to set KP_INT_FLAG in ISR; keypad scanning still works without it.
; -----------------------------
    banksel INTCON
    bcf     INTCON, INTF_BIT
    bsf     INTCON, INTE_BIT
    bsf     INTCON, GIE_BIT

; =========================================================
; MAIN_LOOP
; Execution order:
;   1) Keypad handling (updates DES_TEMP_H/L when committed)
;   2) ADC read (updates AMB_TEMP_H/L)
;   3) Tach update (updates FAN_SPEED periodically)
;   4) Temperature control logic (hysteresis compare, drives outputs)
;   5) 7-seg multiplex refresh
;   6) Optional UART status output
; =========================================================
MAIN_LOOP:
    ; 1) Keypad updates desired setpoint after A ... # sequence
    call    KEYPAD_TASK

    ; 2) Read ambient temperature via ADC (LM35) into AMB_TEMP_H/L
    call    READ_AMBIENT_TEMP

    ; 3) Update fan speed measurement (gate-time based)
    call    TACH_TASK

    ; 4) Apply hysteresis control to HEATER/COOLER
    call    TEMP_CONTROL_LOGIC

    ; 5) Refresh one digit of multiplex display per loop iteration
    nop
    nop
    nop
    nop
    call    SEG7_TASK

    ; 6) Optional UART streaming (lightweight status)
    call    UART_STREAM_STATUS

    goto    MAIN_LOOP

; =========================================================
; ISR
; External interrupt service routine for RB0/INT.
; Function:
;   - If INTF is set, clear it and set KP_INT_FLAG=1.
;   - The main loop / keypad task may use KP_INT_FLAG as a scan trigger.
; =========================================================
ISR:
    banksel INTCON
    btfss   INTCON, INTF_BIT
    goto    ISR_EXIT

    bcf     INTCON, INTF_BIT
    banksel KP_INT_FLAG
    movlw   1
    movwf   KP_INT_FLAG

ISR_EXIT:
    retfie

; =========================================================
; TEMP_CONTROL_LOGIC
; Compares ambient and desired temperature in 0.1°C units (x10 format)
; and drives HEATER/COOLER with hysteresis.
;
; Definitions:
;   DES_x10 = DES_TEMP_H*10 + DES_TEMP_L
;   AMB_x10 = AMB_TEMP_H*10 + AMB_TEMP_L
;
; Control rule (simple OFF-in-band):
;   if AMB > DES + HYST -> COOLER ON, HEATER OFF
;   if AMB < DES - HYST -> HEATER ON, COOLER OFF
;   else                -> both OFF
;
; Requirement Mapping:
;   [R2.1.5-1] HEATER and COOLER shall be controlled based on setpoint and
;             ambient temperature using hysteresis to avoid rapid toggling.
; =========================================================
TEMP_CONTROL_LOGIC:
    ; Build AMB_x10 into TEMP_RAW
    ; TEMP_RAW = (AMB_TEMP_H * 10) + AMB_TEMP_L
    banksel TEMP_RAW
    clrf    TEMP_RAW

    banksel AMB_TEMP_H
    movf    AMB_TEMP_H, W
    movwf   TEMP_WORK            ; loop counter = AMB integer part

AMB_MUL10:
    banksel TEMP_WORK
    movf    TEMP_WORK, F
    btfsc   STATUS, Z_BIT
    goto    AMB_MUL10_DONE
    movlw   10
    banksel TEMP_RAW
    addwf   TEMP_RAW, F
    banksel TEMP_WORK
    decf    TEMP_WORK, F
    goto    AMB_MUL10

AMB_MUL10_DONE:
    banksel AMB_TEMP_L
    movf    AMB_TEMP_L, W
    banksel TEMP_RAW
    addwf   TEMP_RAW, F          ; TEMP_RAW = AMB_x10

    ; Build DES_x10 into TEMP_WORK
    banksel TEMP_WORK
    clrf    TEMP_WORK

    banksel DES_TEMP_H
    movf    DES_TEMP_H, W
    movwf   ADC_VALUE_L          ; reuse as loop counter

DES_MUL10:
    banksel ADC_VALUE_L
    movf    ADC_VALUE_L, F
    btfsc   STATUS, Z_BIT
    goto    DES_MUL10_DONE
    movlw   10
    banksel TEMP_WORK
    addwf   TEMP_WORK, F
    banksel ADC_VALUE_L
    decf    ADC_VALUE_L, F
    goto    DES_MUL10

DES_MUL10_DONE:
    banksel DES_TEMP_L
    movf    DES_TEMP_L, W
    banksel TEMP_WORK
    addwf   TEMP_WORK, F         ; TEMP_WORK = DES_x10

    ; -----------------------------
    ; COOL check: AMB > (DES + HYST)
    ; -----------------------------
    banksel TEMP_WORK
    movf    TEMP_WORK, W
    addlw   HYST_X10              ; threshold_high = DES + HYST
    banksel ADC_VALUE_H
    movwf   ADC_VALUE_H

    ; Evaluate (AMB - threshold_high):
    ;   - if Z=1 -> equal -> not COOL
    ;   - if C=1 and Z=0 -> AMB > threshold_high -> COOL
    banksel ADC_VALUE_H
    movf    ADC_VALUE_H, W
    banksel TEMP_RAW
    subwf   TEMP_RAW, W           ; W = AMB - THIGH
    btfsc   STATUS, Z_BIT
    goto    CHECK_HEAT
    btfsc   STATUS, C_BIT
    goto    DO_COOL

CHECK_HEAT:
    ; -----------------------------
    ; HEAT check: AMB < (DES - HYST)
    ; -----------------------------
    ; Compute threshold_low = DES_x10 - HYST into ADC_VALUE_H
    movlw   HYST_X10
    banksel TEMP_WORK
    subwf   TEMP_WORK, W          ; W = DES - HYST
    banksel ADC_VALUE_H
    movwf   ADC_VALUE_H

    ; Evaluate (AMB - threshold_low):
    ;   - if C=0 -> AMB < threshold_low -> HEAT
    ;   - if C=1 -> AMB >= threshold_low -> inside band -> OFF
    banksel ADC_VALUE_H
    movf    ADC_VALUE_H, W
    banksel TEMP_RAW
    subwf   TEMP_RAW, W           ; W = AMB - TLOW
    btfsc   STATUS, C_BIT
    goto    DO_EQUAL_BAND
    goto    DO_HEAT

DO_COOL:
    ; COOLER ON, HEATER OFF
    banksel PORTA
    bcf     PORTA, HEATER_BIT
    bsf     PORTA, COOLER_BIT
    return

DO_HEAT:
    ; HEATER ON, COOLER OFF
    banksel PORTA
    bsf     PORTA, HEATER_BIT
    bcf     PORTA, COOLER_BIT
    return

DO_EQUAL_BAND:
    ; Inside hysteresis band: both outputs OFF
    banksel PORTA
    bcf     PORTA, HEATER_BIT
    bcf     PORTA, COOLER_BIT
    return

; ---------------------------------------------------------
; Module Includes
; ---------------------------------------------------------
    #include "adc.asm"
    #include "keypad.asm"
    #include "seg7.asm"
    #include "uart.asm"
    #include "tach.asm"

    END

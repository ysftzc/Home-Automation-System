; =========================================================
; tach.asm (REAL gate-time, REAL speed)  - Board #1
; Author      : Yusuf Tuzcu
; Student ID  : 151220202144
; Department  : Electrical and Electronics Engineering
; =========================================================
; Objective:
;   Measure fan rotational speed using the tachometer output connected to
;   RA4/T0CKI. Timer0 counts external pulses, while Timer1 provides a fixed
;   100 ms measurement window (gate time). At the end of each gate, the code
;   computes a scaled speed value and stores it in FAN_SPEED.
;
; Hardware usage:
;   - RA4/T0CKI : Timer0 external clock input (tach pulses)
;   - Timer0    : counts tach pulses during the gate
;   - Timer1    : generates a 100 ms gate window via overflow flag polling
;
; Timing assumptions (used for preload calculation):
;   - FOSC = 4 MHz (XT)  -> instruction clock Fcy = Fosc/4 = 1 MHz
;   - Timer1 prescaler = 1:8 -> Timer1 tick period = 8 us
;   - Gate window = 100 ms -> 100ms / 8us = 12500 ticks
;   - Timer1 preload = 65536 - 12500 = 53036 = 0xCF2C
;
; Tach pulses per revolution (PPR):
;   - Typical PC fan tach output = 2 pulses/revolution
;   - If your fan uses a different PPR, update TACH_PPR and adjust scaling.
;
; Output definition:
;   - FAN_SPEED stores RPM/10 (scaled RPM) to fit into 8-bit range and simplify
;     display formatting on the 7-segment (e.g., show "xxx0" RPM).
;   - For PPR=2 and 100 ms gate:
;       pulses_in_100ms = P
;       RPM     = P * 300
;       RPM/10  = P * 30  => FAN_SPEED = P*30 (clamped to 255)
;
; Requirement Mapping:
;   [R2.1.3-1] Fan speed shall be measured and displayed (RPM mode uses FAN_SPEED).
;   [R2.1.4-1] Fan speed may be transmitted over UART as part of status reporting.
; =========================================================

    PROCESSOR   16F877A
    #include    <xc.inc>
    #include    "config.inc"

    GLOBAL  TACH_INIT
    GLOBAL  TACH_TASK

    ; Shared variables are allocated in main.asm (udata_bank0)
    GLOBAL  TACH_GATE_L
    GLOBAL  TACH_GATE_H
    GLOBAL  TACH_COUNT
    GLOBAL  FAN_SPEED
    GLOBAL  TEMP_RAW
    GLOBAL  TEMP_WORK

    PSECT   code

; ---------------------------------------------------------
; Timer1 preload constants for a 100 ms overflow interval
; (valid for 4 MHz XT and Timer1 prescaler 1:8)
; ---------------------------------------------------------
TMR1_PRELOAD_H   EQU 0xCF
TMR1_PRELOAD_L   EQU 0x2C

; ---------------------------------------------------------
; Tachometer pulses per revolution (typical PC fan = 2)
; ---------------------------------------------------------
TACH_PPR         EQU 2        ; update if the fan tach output differs

; ---------------------------------------------------------
; Implementation note:
;   - TACH_GATE_H is reused as the Timer0 overflow counter inside a gate window.
;   - TACH_GATE_L is not used in this version (kept for compatibility).
; ---------------------------------------------------------


; =========================================================
; TACH_INIT
; Initializes tach measurement:
;   - Clears Timer0 and overflow counters
;   - Configures Timer1 for 100 ms gate via preload + polling
;
; Note:
;   Timer0 external clock selection (T0CS=1, T0SE edge, etc.) is configured
;   in main.asm via OPTION_REG.
; =========================================================
TACH_INIT:
    ; Clear overflow counter and unused scratch byte
    banksel TACH_GATE_L
    clrf    TACH_GATE_L
    clrf    TACH_GATE_H         ; counts Timer0 overflows during the gate

    ; Clear Timer0 pulse counter (counts external tach pulses on RA4/T0CKI)
    banksel TMR0
    clrf    TMR0

    ; ---- Timer1 setup (100 ms gate) ----
    ; T1CON:
    ;   T1CKPS1:T1CKPS0 = 11 -> 1:8 prescaler
    ;   TMR1CS          = 0  -> internal clock (Fosc/4)
    ;   TMR1ON          = 1  -> enable Timer1
    banksel T1CON
    movlw   0b00110001
    movwf   T1CON

    ; Preload Timer1 so it overflows after ~100 ms
    banksel TMR1H
    movlw   TMR1_PRELOAD_H
    movwf   TMR1H
    banksel TMR1L
    movlw   TMR1_PRELOAD_L
    movwf   TMR1L

    ; Clear Timer1 overflow flag (PIR1.TMR1IF = bit0)
    banksel PIR1
    bcf     PIR1, 0

    ; Initialize output
    banksel FAN_SPEED
    clrf    FAN_SPEED
    return


; =========================================================
; TACH_TASK
; Called periodically from the main loop.
; Responsibilities:
;   1) Track Timer0 overflow events (extends 8-bit pulse count within the window)
;   2) Detect end of 100 ms gate (Timer1 overflow flag)
;   3) Sample pulse count and compute FAN_SPEED = RPM/10
;   4) Clamp result to 255 when the measured value exceeds 8-bit display range
; =========================================================
TACH_TASK:
    ; --------------------------------
    ; 1) Count Timer0 overflows during the gate window
    ; INTCON.T0IF (bit2) is set when TMR0 rolls over from 0xFF to 0x00.
    ; --------------------------------
    banksel INTCON
    btfss   INTCON, 2           ; T0IF set?
    goto    _CHK_GATE
    bcf     INTCON, 2           ; clear T0IF
    banksel TACH_GATE_H
    incf    TACH_GATE_H, F      ; overflow_count++

_CHK_GATE:
    ; --------------------------------
    ; 2) Check if 100 ms gate elapsed (Timer1 overflow)
    ; PIR1.TMR1IF (bit0) is set when Timer1 overflows.
    ; --------------------------------
    banksel PIR1
    btfss   PIR1, 0             ; TMR1IF set?
    return

    ; Gate elapsed: clear flag for next interval
    bcf     PIR1, 0

    ; Reload Timer1 for the next 100 ms gate window
    banksel TMR1H
    movlw   TMR1_PRELOAD_H
    movwf   TMR1H
    banksel TMR1L
    movlw   TMR1_PRELOAD_L
    movwf   TMR1L

    ; --------------------------------
    ; 3) Sample pulses in this 100 ms window
    ; pulses = (overflow_count * 256) + TMR0
    ; We store low byte in TACH_COUNT and use overflow_count to clamp.
    ; --------------------------------
    banksel TMR0
    movf    TMR0, W
    banksel TACH_COUNT
    movwf   TACH_COUNT          ; low 8-bit pulse count in window

    ; Reset Timer0 and overflow counter for the next window
    banksel TMR0
    clrf    TMR0

    banksel TACH_GATE_H
    movf    TACH_GATE_H, W
    banksel TEMP_WORK
    movwf   TEMP_WORK           ; TEMP_WORK = overflow_count
    banksel TACH_GATE_H
    clrf    TACH_GATE_H

    ; If overflow_count != 0, pulse count exceeded 255 -> clamp speed
    banksel TEMP_WORK
    movf    TEMP_WORK, F
    btfsc   STATUS, Z_BIT
    goto    _NO_OVF
    banksel FAN_SPEED
    movlw   255
    movwf   FAN_SPEED
    return

_NO_OVF:
    ; --------------------------------
    ; 4) Compute scaled speed: FAN_SPEED = RPM/10
    ;
    ; For 100 ms gate:
    ;   RPM/10 = pulses * (60 / PPR)
    ; For PPR=2: RPM/10 = pulses * 30
    ;
    ; Implementation approach:
    ;   Multiply pulses by 30 using shifts and adds:
    ;     30P = 16P + 8P + 4P + 2P
    ;
    ; NOTE:
    ;   This routine assumes PPR=2. For other PPR values, add either:
    ;     - a division routine, or
    ;     - dedicated scaling branches for supported PPR values.
    ; --------------------------------

    ; Load P (pulses) into TEMP_RAW
    banksel TACH_COUNT
    movf    TACH_COUNT, W
    banksel TEMP_RAW
    movwf   TEMP_RAW            ; TEMP_RAW = P

    ; Clear accumulator (low byte only)
    banksel TEMP_WORK
    clrf    TEMP_WORK

    ; ---- add 16P ----
    banksel TEMP_RAW
    movf    TEMP_RAW, W
    banksel TACH_COUNT
    movwf   TACH_COUNT          ; shift workspace = P
    rlf     TACH_COUNT, F       ; 2P
    rlf     TACH_COUNT, F       ; 4P
    rlf     TACH_COUNT, F       ; 8P
    rlf     TACH_COUNT, F       ; 16P
    movf    TACH_COUNT, W
    banksel TEMP_WORK
    addwf   TEMP_WORK, F

    ; ---- add 8P ----
    banksel TEMP_RAW
    movf    TEMP_RAW, W
    banksel TACH_COUNT
    movwf   TACH_COUNT
    rlf     TACH_COUNT, F       ; 2P
    rlf     TACH_COUNT, F       ; 4P
    rlf     TACH_COUNT, F       ; 8P
    movf    TACH_COUNT, W
    banksel TEMP_WORK
    addwf   TEMP_WORK, F

    ; ---- add 4P ----
    banksel TEMP_RAW
    movf    TEMP_RAW, W
    banksel TACH_COUNT
    movwf   TACH_COUNT
    rlf     TACH_COUNT, F       ; 2P
    rlf     TACH_COUNT, F       ; 4P
    movf    TACH_COUNT, W
    banksel TEMP_WORK
    addwf   TEMP_WORK, F

    ; ---- add 2P ----
    banksel TEMP_RAW
    movf    TEMP_RAW, W
    banksel TACH_COUNT
    movwf   TACH_COUNT
    rlf     TACH_COUNT, F       ; 2P
    movf    TACH_COUNT, W
    banksel TEMP_WORK
    addwf   TEMP_WORK, F

    ; TEMP_WORK contains P*30 modulo 256.
    ; To avoid wrap-around, clamp if P >= 9 (since 9*30 = 270 > 255).
    banksel TEMP_RAW
    movf    TEMP_RAW, W
    sublw   8                   ; W = 8 - P
    btfss   STATUS, C_BIT       ; C=0 => P > 8 => clamp
    goto    _CLAMP_255

    ; Valid range: FAN_SPEED = P*30
    banksel TEMP_WORK
    movf    TEMP_WORK, W
    banksel FAN_SPEED
    movwf   FAN_SPEED
    return

_CLAMP_255:
    banksel FAN_SPEED
    movlw   255
    movwf   FAN_SPEED
    return

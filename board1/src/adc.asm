; =========================================================
; adc.asm (PIN MAPPING v2)  - Board #1
; Author      : Yusuf Tuzcu
; Student ID  : 151220202144
; Department  : Electrical and Electronics Engineering
; =========================================================
; Overview:
;   Ambient temperature acquisition for PIC16F877A using LM35 on AN0 (RA0).
;   Performs a 10-bit ADC conversion, then converts the result to:
;     - AMB_TEMP_H : integer temperature (°C)
;     - AMB_TEMP_L : first decimal digit (0..9)
;
; Functional Traceability:
;   [R2.1.1-4] Ambient temperature must be sampled periodically and the latest
;             value must be stored in memory for the control/display tasks.
;
; I/O Mapping:
;   Input  : LM35 sensor -> RA0 / AN0  (Vref = Vdd/Vss)
;   Output : AMB_TEMP_H (0..99 typical), AMB_TEMP_L (0..9)
;
; Conversion Model:
;   - ADC result is right-justified (ADFM=1): ADRESH:ADRESL = 10-bit N
;   - temp_x10 = (N * 5000) / 1024
;       N * 5000  -> converts ADC code to millivolts for a 5V reference
;       LM35 = 10 mV/°C  => millivolts equals (°C * 10)
;   - integer = temp_x10 / 10
;   - frac    = temp_x10 % 10
; =========================================================


    PSECT   udata_bank0
; -------------------------
; Local working registers
; -------------------------
ADC_MUL0:    ds 1     ; 24-bit multiply accumulator (LSB)
ADC_MUL1:    ds 1     ; 24-bit multiply accumulator (MID)
ADC_MUL2:    ds 1     ; 24-bit multiply accumulator (MSB)

ADC_N_L:     ds 1     ; 10-bit ADC value copy (LSB)
ADC_N_H:     ds 1     ; 10-bit ADC value copy (MSB; only bits[1:0] used)

ADD_L:       ds 1     ; 24-bit shift-add operand (LSB)  - initialized to 5000
ADD_M:       ds 1     ; 24-bit shift-add operand (MID)
ADD_H:       ds 1     ; 24-bit shift-add operand (MSB)

TEMPX10_L:   ds 1     ; temp_x10 (LSB)
TEMPX10_H:   ds 1     ; temp_x10 (MSB)

DIV_TMP_L:   ds 1     ; temp_x10 working copy for /10 and %10 (LSB)
DIV_TMP_H:   ds 1     ; temp_x10 working copy for /10 and %10 (MSB)

BITCNT:      ds 1     ; multiply loop counter (10 iterations for 10-bit ADC)
SHCNT:       ds 1     ; shift counter for /1024 (right shift by 10)

    PSECT   code

; =========================================================
; ADC_INIT
; Configures ADC hardware for:
;   - AN0 enabled as analog input, other pins digital
;   - Vref = Vdd/Vss
;   - Right-justified result (ADFM=1)
;   - ADC clock = Fosc/32
;   - Selected channel = AN0
;   - ADC module enabled (ADON=1)
;
; Traceability:
;   [R2.1.1-4] Initializes ADC subsystem required by periodic temperature reads.
; =========================================================
ADC_INIT:
    ; ADCON1:
    ;   ADFM=1    -> right-justified (ADRESH:ADRESL holds 10-bit N)
    ;   PCFG=1110 -> AN0 analog, others digital, Vref=Vdd/Vss
    banksel ADCON1
    movlw   0b10001110
    movwf   ADCON1

    ; ADCON0:
    ;   ADCS=10 -> Fosc/32 conversion clock
    ;   CHS=000 -> AN0 channel select
    ;   ADON=1  -> enable ADC module
    banksel ADCON0
    movlw   0b10000001
    movwf   ADCON0

    return


; =========================================================
; READ_AMBIENT_TEMP
; Performs a single ADC conversion on AN0 and updates:
;   AMB_TEMP_H (integer °C)
;   AMB_TEMP_L (first decimal digit)
;
; Processing Steps:
;   1) Start conversion and poll GO/DONE until complete
;   2) Read 10-bit ADC value N from ADRESH:ADRESL (right-justified)
;   3) Compute temp_x10 = (N * 5000) / 1024
;      - Implemented using shift-add multiplication (24-bit accumulator)
;      - Division by 1024 is implemented as 10 logical right shifts
;   4) Compute:
;        AMB_TEMP_H = temp_x10 / 10
;        AMB_TEMP_L = temp_x10 % 10
;      - Implemented using repeated subtraction by 10
;
; Traceability:
;   [R2.1.1-4] Provides the periodic ambient temperature update routine.
; =========================================================
READ_AMBIENT_TEMP:
    ; ---- Start ADC conversion on AN0 ----
    banksel ADCON0
    bsf     ADCON0, GO_BIT          ; GO/DONE=1 -> start conversion

ADC_WAIT:
    btfsc   ADCON0, GO_BIT          ; wait while conversion is running
    goto    ADC_WAIT

    ; ---- Read 10-bit ADC result (ADFM=1) ----
    banksel ADRESL
    movf    ADRESL, W               ; low 8 bits
    banksel ADC_VALUE_L
    movwf   ADC_VALUE_L

    banksel ADRESH
    movf    ADRESH, W               ; high byte (valid bits: [1:0])
    andlw   0x03                    ; keep only 2 MSBs of 10-bit result
    banksel ADC_VALUE_H
    movwf   ADC_VALUE_H

    ; ---- Copy ADC result into local N registers ----
    banksel ADC_N_L
    movf    ADC_VALUE_L, W
    movwf   ADC_N_L
    movf    ADC_VALUE_H, W
    movwf   ADC_N_H

    ; =========================================================
    ; Multiply: (N * 5000)
    ; 5000d = 0x1388 => ADD = 0x00:0x13:0x88 (24-bit)
    ; Accumulator: ADC_MUL2:ADC_MUL1:ADC_MUL0
    ; =========================================================

    ; clear 24-bit accumulator
    banksel ADC_MUL0
    clrf    ADC_MUL0
    clrf    ADC_MUL1
    clrf    ADC_MUL2

    ; load addend = 5000
    banksel ADD_L
    movlw   0x88
    movwf   ADD_L
    movlw   0x13
    movwf   ADD_M
    clrf    ADD_H

    ; 10-bit multiply loop
    movlw   10
    movwf   BITCNT

MUL_LOOP:
    ; if (N LSB = 1) then ACC += ADD
    banksel ADC_N_L
    btfss   ADC_N_L, 0
    goto    MUL_SKIP_ADD

    ; 24-bit addition with carry propagation
    banksel ADD_L
    movf    ADD_L, W
    banksel ADC_MUL0
    addwf   ADC_MUL0, F

    banksel ADD_M
    movf    ADD_M, W
    banksel ADC_MUL1
    btfsc   STATUS, C_BIT
    addlw   1
    addwf   ADC_MUL1, F

    banksel ADD_H
    movf    ADD_H, W
    banksel ADC_MUL2
    btfsc   STATUS, C_BIT
    addlw   1
    addwf   ADC_MUL2, F

MUL_SKIP_ADD:
    ; N >>= 1 (consume next multiplier bit)
    banksel ADC_N_H
    bcf     STATUS, C_BIT
    rrf     ADC_N_H, F
    banksel ADC_N_L
    rrf     ADC_N_L, F

    ; ADD <<= 1 (next weight)
    banksel ADD_L
    bcf     STATUS, C_BIT
    rlf     ADD_L, F
    banksel ADD_M
    rlf     ADD_M, F
    banksel ADD_H
    rlf     ADD_H, F

    ; loop control
    banksel BITCNT
    decfsz  BITCNT, F
    goto    MUL_LOOP

    ; =========================================================
    ; Divide by 1024 (shift right by 10) to obtain:
    ;   temp_x10 = (N * 5000) / 1024
    ; =========================================================
    movlw   10
    movwf   SHCNT

SHR10_LOOP:
    ; 24-bit logical shift right by 1: MUL2 -> MUL1 -> MUL0
    banksel ADC_MUL2
    bcf     STATUS, C_BIT
    rrf     ADC_MUL2, F
    banksel ADC_MUL1
    rrf     ADC_MUL1, F
    banksel ADC_MUL0
    rrf     ADC_MUL0, F

    banksel SHCNT
    decfsz  SHCNT, F
    goto    SHR10_LOOP

    ; store temp_x10 (lower 16 bits sufficient here)
    banksel TEMPX10_L
    movf    ADC_MUL0, W
    movwf   TEMPX10_L
    movf    ADC_MUL1, W
    movwf   TEMPX10_H

    ; =========================================================
    ; Convert temp_x10 into:
    ;   AMB_TEMP_H = temp_x10 / 10
    ;   AMB_TEMP_L = temp_x10 % 10
    ; Using repeated subtraction by 10 (16-bit).
    ; =========================================================

    ; working copy
    banksel DIV_TMP_L
    movf    TEMPX10_L, W
    movwf   DIV_TMP_L
    movf    TEMPX10_H, W
    movwf   DIV_TMP_H

    ; clear quotient
    banksel AMB_TEMP_H
    clrf    AMB_TEMP_H

DIV10_LOOP:
    ; if high byte != 0 then value >= 256, subtraction by 10 is valid
    banksel DIV_TMP_H
    movf    DIV_TMP_H, F
    btfss   STATUS, Z_BIT
    goto    DIV10_SUB

    ; high byte == 0: test low >= 10
    banksel DIV_TMP_L
    movlw   10
    subwf   DIV_TMP_L, W
    btfss   STATUS, C_BIT
    goto    DIV10_DONE

DIV10_SUB:
    ; DIV_TMP -= 10 (16-bit)
    banksel DIV_TMP_L
    movlw   10
    subwf   DIV_TMP_L, F
    btfss   STATUS, C_BIT
    decf    DIV_TMP_H, F

    ; quotient++
    banksel AMB_TEMP_H
    incf    AMB_TEMP_H, F
    goto    DIV10_LOOP

DIV10_DONE:
    ; remainder -> fractional digit
    banksel AMB_TEMP_L
    movf    DIV_TMP_L, W
    movwf   AMB_TEMP_L

    return

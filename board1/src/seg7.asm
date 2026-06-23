; =========================================================
; seg7.asm (3-mode display: DES -> AMB -> RPM)  - Board #1
; Author      : Yusuf Tuzcu
; Student ID  : 151220202144
; Department  : Electrical and Electronics Engineering
; =========================================================
; Hardware mapping:
;   Segments : PORTD (RD0..RD7 -> a..g,dp)
;   Digits   : PORTC (RC2..RC5 -> DIG1..DIG4), active HIGH multiplexing
;
; Display behavior:
;   The display cycles through three modes:
;     1) Desired temperature (DES)
;     2) Ambient temperature (AMB)
;     3) Fan speed (RPM/Scaled RPM)
;   Each mode is shown for ~2 seconds (software timing).
;
; Requirement Mapping:
;   [R2.1.3-1] System shall display desired temperature, ambient temperature,
;             and fan speed on the 7-segment display.
; =========================================================

    PROCESSOR   16F877A
    #include    <xc.inc>
    #include    "config.inc"

    ; Shared variables allocated in main.asm (udata_bank0)
    GLOBAL  DES_TEMP_H, DES_TEMP_L
    GLOBAL  AMB_TEMP_H, AMB_TEMP_L
    GLOBAL  FAN_SPEED
    GLOBAL  DISP_MODE, DISP_TIMER_L, DISP_TIMER_H

    ; Local display buffers (segment patterns for each digit)
    PSECT   udata_bank0
SEG_BUF0:    ds 1            ; Digit1 buffer (least significant position)
SEG_BUF1:    ds 1            ; Digit2 buffer
SEG_BUF2:    ds 1            ; Digit3 buffer
SEG_BUF3:    ds 1            ; Digit4 buffer (most significant position)
SEG_MUX_IDX: ds 1            ; Multiplex index (0..3)

    ; Temporary decimal digits used by BIN->DEC routines
TMP_DIG0:    ds 1            ; ones digit
TMP_DIG1:    ds 1            ; tens digit

    PSECT   code

; ---------------------------------------------------------
; Display mode identifiers
; ---------------------------------------------------------
DISP_DESIRED    EQU 0
DISP_AMBIENT    EQU 1
DISP_RPM        EQU 2

; ---------------------------------------------------------
; Software timing parameters for mode switching
; - DISP_TIMER_L increments each SEG7_TASK call
; - Once it reaches MODE_L_PRESCALE, DISP_TIMER_H increments
; - Once DISP_TIMER_H reaches MODE_H_TICKS_2S, the mode advances
;
; Notes:
;   Increasing MODE_L_PRESCALE slows down mode switching.
;   MODE_H_TICKS_2S depends on the main loop speed; typical range is 10..20.
; ---------------------------------------------------------
MODE_L_PRESCALE  EQU 200
MODE_H_TICKS_2S  EQU 12

; =========================================================
; SEG7_INIT
; Initializes display buffers, mode state, and outputs.
; - Clears segment buffers and multiplex index
; - Resets mode timers
; - Forces all digits OFF and clears segment lines
; - Builds initial display buffer for the default mode (DES)
; =========================================================
SEG7_INIT:
    banksel SEG_BUF0
    clrf    SEG_BUF0
    clrf    SEG_BUF1
    clrf    SEG_BUF2
    clrf    SEG_BUF3
    clrf    SEG_MUX_IDX

    banksel DISP_MODE
    clrf    DISP_MODE
    clrf    DISP_TIMER_L
    clrf    DISP_TIMER_H

    call    SEG7_ALL_DIGITS_OFF
    call    SEG7_BLANK_SEGMENTS
    call    BUILD_DISPLAY_BUFFER
    return

; =========================================================
; SEG7_TASK
; Must be called frequently from the main loop.
; Responsibilities:
;   1) Update mode timing (DES -> AMB -> RPM)
;   2) Build segment patterns for the active mode
;   3) Perform digit multiplexing (one digit per call)
; =========================================================
SEG7_TASK:
    call    UPDATE_DISPLAY_MODE
    call    BUILD_DISPLAY_BUFFER

    ; Avoid ghosting: disable all digits before changing segment lines
    call    SEG7_ALL_DIGITS_OFF

    ; Select which digit to refresh based on SEG_MUX_IDX
    banksel SEG_MUX_IDX
    movf    SEG_MUX_IDX, W
    xorlw   0
    btfsc   STATUS, Z_BIT
    goto    _MUX_D1
    movf    SEG_MUX_IDX, W
    xorlw   1
    btfsc   STATUS, Z_BIT
    goto    _MUX_D2
    movf    SEG_MUX_IDX, W
    xorlw   2
    btfsc   STATUS, Z_BIT
    goto    _MUX_D3
    goto    _MUX_D4

_MUX_D1:
    ; Digit1 (least significant position)
    banksel SEG_BUF0
    movf    SEG_BUF0, W
    call    SEG7_WRITE_PATTERN
    call    DIGIT1_ON
    goto    _MUX_NEXT

_MUX_D2:
    banksel SEG_BUF1
    movf    SEG_BUF1, W
    call    SEG7_WRITE_PATTERN
    call    DIGIT2_ON
    goto    _MUX_NEXT

_MUX_D3:
    banksel SEG_BUF2
    movf    SEG_BUF2, W
    call    SEG7_WRITE_PATTERN
    call    DIGIT3_ON
    goto    _MUX_NEXT

_MUX_D4:
    ; Digit4 (most significant position)
    banksel SEG_BUF3
    movf    SEG_BUF3, W
    call    SEG7_WRITE_PATTERN
    call    DIGIT4_ON

_MUX_NEXT:
    ; Advance multiplex index 0..3 (wrap to 0 after 3)
    banksel SEG_MUX_IDX
    incf    SEG_MUX_IDX, F
    movlw   4
    subwf   SEG_MUX_IDX, W
    btfss   STATUS, C_BIT      ; if SEG_MUX_IDX < 4 -> done
    return
    clrf    SEG_MUX_IDX        ; wrap back to 0
    return

; =========================================================
; UPDATE_DISPLAY_MODE
; Implements software timing to change the displayed mode.
; - L-counter counts up to MODE_L_PRESCALE
; - H-counter counts up to MODE_H_TICKS_2S
; - Mode cycles: 0 (DES) -> 1 (AMB) -> 2 (RPM) -> back to 0
; =========================================================
UPDATE_DISPLAY_MODE:
    banksel DISP_TIMER_L
    incf    DISP_TIMER_L, F
    movlw   MODE_L_PRESCALE
    subwf   DISP_TIMER_L, W
    btfss   STATUS, C_BIT
    return

    ; L reached prescale: reset L and increment H
    clrf    DISP_TIMER_L
    incf    DISP_TIMER_H, F

    movlw   MODE_H_TICKS_2S
    subwf   DISP_TIMER_H, W
    btfss   STATUS, C_BIT
    return

    ; H reached limit: reset H and advance mode
    clrf    DISP_TIMER_H
    banksel DISP_MODE
    incf    DISP_MODE, F
    movlw   3
    subwf   DISP_MODE, W
    btfss   STATUS, C_BIT
    goto    _UDM_DONE
    clrf    DISP_MODE          ; wrap after mode 2
_UDM_DONE:
    return

; =========================================================
; BUILD_DISPLAY_BUFFER
; Populates SEG_BUFx with segment patterns for the current mode.
;
; Display formats:
;   - DES / AMB:
;       " TT.F"
;       D4 blank, D3 tens, D2 ones + decimal point, D1 fractional digit
;   - RPM:
;       " 000"
;       D4 blank, D3 hundreds, D2 tens, D1 ones
;
; Note:
;   FAN_SPEED is a scaled value (e.g., RPM/10) depending on tach module.
; =========================================================
BUILD_DISPLAY_BUFFER:
    banksel DISP_MODE
    movf    DISP_MODE, W
    xorlw   DISP_DESIRED
    btfsc   STATUS, Z_BIT
    goto    _BUILD_DES

    banksel DISP_MODE
    movf    DISP_MODE, W
    xorlw   DISP_AMBIENT
    btfsc   STATUS, Z_BIT
    goto    _BUILD_AMB

    goto    _BUILD_RPM

_BUILD_DES:
    ; D4 = blank
    movlw   0x0F
    call    DIGIT_TO_PATTERN
    banksel SEG_BUF3
    movwf   SEG_BUF3

    ; Convert DES_TEMP_H (0..99) into tens/ones -> TMP_DIG1/TMP_DIG0
    banksel DES_TEMP_H
    movf    DES_TEMP_H, W
    call    BIN2DEC_2DIG

    ; D3 = tens digit
    banksel TMP_DIG1
    movf    TMP_DIG1, W
    call    DIGIT_TO_PATTERN
    banksel SEG_BUF2
    movwf   SEG_BUF2

    ; D2 = ones digit + decimal point
    banksel TMP_DIG0
    movf    TMP_DIG0, W
    call    DIGIT_TO_PATTERN
    call    ADD_DP_TO_PATTERN
    banksel SEG_BUF1
    movwf   SEG_BUF1

    ; D1 = fractional digit (0..9)
    banksel DES_TEMP_L
    movf    DES_TEMP_L, W
    call    DIGIT_TO_PATTERN
    banksel SEG_BUF0
    movwf   SEG_BUF0
    return

_BUILD_AMB:
    ; D4 = blank
    movlw   0x0F
    call    DIGIT_TO_PATTERN
    banksel SEG_BUF3
    movwf   SEG_BUF3

    ; Convert AMB_TEMP_H (0..99) into tens/ones -> TMP_DIG1/TMP_DIG0
    banksel AMB_TEMP_H
    movf    AMB_TEMP_H, W
    call    BIN2DEC_2DIG

    ; D3 = tens digit
    banksel TMP_DIG1
    movf    TMP_DIG1, W
    call    DIGIT_TO_PATTERN
    banksel SEG_BUF2
    movwf   SEG_BUF2

    ; D2 = ones digit + decimal point
    banksel TMP_DIG0
    movf    TMP_DIG0, W
    call    DIGIT_TO_PATTERN
    call    ADD_DP_TO_PATTERN
    banksel SEG_BUF1
    movwf   SEG_BUF1

    ; D1 = fractional digit (0..9)
    banksel AMB_TEMP_L
    movf    AMB_TEMP_L, W
    call    DIGIT_TO_PATTERN
    banksel SEG_BUF0
    movwf   SEG_BUF0
    return

_BUILD_RPM:
    ; D4 = blank
    movlw   0x0F
    call    DIGIT_TO_PATTERN
    banksel SEG_BUF3
    movwf   SEG_BUF3

    ; Convert FAN_SPEED (0..255) into hundreds/tens/ones -> TMP_DIG2/TMP_DIG1/TMP_DIG0
    ; Note: FAN_SPEED is initialized to 0 until tach module updates it.
    banksel FAN_SPEED
    movf    FAN_SPEED, W
    call    BIN2DEC_3DIG        ; TMP_DIG2=hundreds, TMP_DIG1=tens, TMP_DIG0=ones

    ; D3 = hundreds, D2 = tens, D1 = ones
    banksel TMP_DIG2
    movf    TMP_DIG2, W
    call    DIGIT_TO_PATTERN
    banksel SEG_BUF2
    movwf   SEG_BUF2

    banksel TMP_DIG1
    movf    TMP_DIG1, W
    call    DIGIT_TO_PATTERN
    banksel SEG_BUF1
    movwf   SEG_BUF1

    banksel TMP_DIG0
    movf    TMP_DIG0, W
    call    DIGIT_TO_PATTERN
    banksel SEG_BUF0
    movwf   SEG_BUF0
    return

; =========================================================
; BIN2DEC_2DIG
; Converts an 8-bit value in W (0..255) into two decimal digits.
; Output:
;   TMP_DIG1 = tens
;   TMP_DIG0 = ones
; Method:
;   Repeated subtraction by 10.
; =========================================================
BIN2DEC_2DIG:
    banksel TMP_DIG1
    clrf    TMP_DIG1
    banksel TMP_DIG0
    movwf   TMP_DIG0

_B2D2_LOOP:
    banksel TMP_DIG0
    movlw   10
    subwf   TMP_DIG0, W
    btfss   STATUS, C_BIT      ; if TMP_DIG0 < 10 -> done
    return
    movlw   10
    subwf   TMP_DIG0, F        ; TMP_DIG0 -= 10
    banksel TMP_DIG1
    incf    TMP_DIG1, F        ; tens++
    goto    _B2D2_LOOP

; =========================================================
; BIN2DEC_3DIG
; Converts an 8-bit value in W (0..255) into three decimal digits.
; Output:
;   TMP_DIG2 = hundreds
;   TMP_DIG1 = tens
;   TMP_DIG0 = ones
; Method:
;   Repeated subtraction by 100 then by 10.
; =========================================================
TMP_DIG2: ds 1

BIN2DEC_3DIG:
    banksel TMP_DIG2
    clrf    TMP_DIG2
    banksel TMP_DIG1
    clrf    TMP_DIG1
    banksel TMP_DIG0
    movwf   TMP_DIG0

    ; hundreds digit calculation (subtract 100 repeatedly)
_B2D3_H:
    banksel TMP_DIG0
    movlw   100
    subwf   TMP_DIG0, W
    btfss   STATUS, C_BIT
    goto    _B2D3_T
    movlw   100
    subwf   TMP_DIG0, F
    banksel TMP_DIG2
    incf    TMP_DIG2, F
    goto    _B2D3_H

    ; tens digit calculation (subtract 10 repeatedly)
_B2D3_T:
_B2D3_T_LOOP:
    banksel TMP_DIG0
    movlw   10
    subwf   TMP_DIG0, W
    btfss   STATUS, C_BIT
    return
    movlw   10
    subwf   TMP_DIG0, F
    banksel TMP_DIG1
    incf    TMP_DIG1, F
    goto    _B2D3_T_LOOP

; =========================================================
; DIGIT_TO_PATTERN
; Input:
;   W = 0..9 or 0x0F (special value for "blank")
; Output:
;   W = 7-segment pattern (a..g,dp) for PORTD
; Notes:
;   Uses a computed jump table (PCLATH + PCL) to return retlw patterns.
; =========================================================
DIGIT_TO_PATTERN:
    xorlw   0x0F
    btfsc   STATUS, Z_BIT
    goto    _PAT_BLANK
    xorlw   0x0F

    movwf   TMP_DIG0

    movlw   HIGH(_PAT_TABLE)
    movwf   PCLATH
    movlw   LOW(_PAT_TABLE)
    addwf   TMP_DIG0, W
    movwf   PCL

_PAT_TABLE:
    retlw   0b00111111  ; 0
    retlw   0b00000110  ; 1
    retlw   0b01011011  ; 2
    retlw   0b01001111  ; 3
    retlw   0b01100110  ; 4
    retlw   0b01101101  ; 5
    retlw   0b01111101  ; 6
    retlw   0b00000111  ; 7
    retlw   0b01111111  ; 8
    retlw   0b01101111  ; 9

_PAT_BLANK:
    movlw   0                    ; all segments OFF
    return

; =========================================================
; ADD_DP_TO_PATTERN
; Sets the decimal point bit in the current segment pattern.
; Assumes dp is mapped to bit7 (RD7).
; =========================================================
ADD_DP_TO_PATTERN:
    iorlw   0b10000000
    return

; =========================================================
; SEG7_WRITE_PATTERN
; Writes segment pattern (W) to PORTD.
; =========================================================
SEG7_WRITE_PATTERN:
    banksel PORTD
    movwf   PORTD
    return

; =========================================================
; SEG7_ALL_DIGITS_OFF
; Disables all digit enable lines to prevent ghosting while updating segments.
; =========================================================
SEG7_ALL_DIGITS_OFF:
    banksel PORTC
    bcf     PORTC, DIG1_BIT
    bcf     PORTC, DIG2_BIT
    bcf     PORTC, DIG3_BIT
    bcf     PORTC, DIG4_BIT
    return

; =========================================================
; SEG7_BLANK_SEGMENTS
; Clears all segment outputs on PORTD (all segments OFF).
; =========================================================
SEG7_BLANK_SEGMENTS:
    banksel PORTD
    clrf    PORTD
    return

; =========================================================
; Digit enable helpers (active HIGH)
; Only one digit should be ON at a time during multiplexing.
; =========================================================
DIGIT1_ON:
    banksel PORTC
    bsf     PORTC, DIG1_BIT
    return

DIGIT2_ON:
    banksel PORTC
    bsf     PORTC, DIG2_BIT
    return

DIGIT3_ON:
    banksel PORTC
    bsf     PORTC, DIG3_BIT
    return

DIGIT4_ON:
    banksel PORTC
    bsf     PORTC, DIG4_BIT
    return

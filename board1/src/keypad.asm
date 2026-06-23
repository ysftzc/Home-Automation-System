; =========================================================
; keypad.asm (PIN MAPPING v2)  - Board #1
; Author      : Yusuf Tuzcu
; Student ID  : 151220202144
; Department  : Electrical and Electronics Engineering
; =========================================================
; Target MCU  : PIC16F877A (XC8 pic-as)
; Interface  :
;   PORTB keypad wiring (4x4):
;     - Rows : RB0..RB3 as inputs  (PORTB internal pull-ups ON)
;     - Cols : RB4..RB7 as outputs (scan: drive one column LOW at a time)
;
; User input protocol:
;   - Press 'A' to start entering the desired temperature
;   - Enter two digits for integer part (D1 D2) -> 10..50
;   - Optional: press '*' then one digit for fractional part (0..9)
;   - Press '#' to commit (write setpoint)
;
; Outputs written by this module (globals in main.asm):
;   - DES_TEMP_H : integer part (10..50)
;   - DES_TEMP_L : fractional digit (0..9)  -> represents 0.1°C steps
;
; Return conventions:
;   - KEYPAD_SCAN returns key code in W:
;       0..9   digits
;       10..13 A..D
;       14     '*'
;       15     '#'
;       0xFF   no key
; =========================================================

    PSECT   code

; ---------------------------------------------------------
; Keypad entry state machine
; ---------------------------------------------------------
KP_STATE_IDLE   EQU 0          ; waiting for 'A'
KP_STATE_INT    EQU 1          ; collecting integer digits D1,D2
KP_STATE_FRAC   EQU 2          ; collecting fractional digit after '*'

; ---------------------------------------------------------
; KEY_FLAGS bit allocation
; ---------------------------------------------------------
KEY_HELD_BIT    EQU 0          ; 1 => key is being held; used for de-bounce/repeat block

; =========================================================
; KEYPAD_INIT
; - Configures PORTB directions for keypad scan
; - Initializes state machine buffers and flags
; =========================================================
KEYPAD_INIT:
    ; RB0..RB3 inputs (rows), RB4..RB7 outputs (cols)
    banksel TRISB
    movlw   0b00001111
    movwf   TRISB

    ; idle column lines HIGH (RB4..RB7 = 1)
    banksel PORTB
    movlw   0b11110000
    iorwf   PORTB, F

    ; reset state machine
    banksel KEY_STATE
    clrf    KEY_STATE

    ; clear input buffers (0xFF indicates empty)
    movlw   0xFF
    movwf   KEY_BUFFER0
    movwf   KEY_BUFFER1
    movwf   KEY_BUFFER2

    ; clear "key held" flag
    banksel KEY_FLAGS
    bcf     KEY_FLAGS, KEY_HELD_BIT
    return

; =========================================================
; KEYPAD_SCAN
; Scans the 4x4 keypad using column-drive / row-read method.
; Steps:
;   1) Drive one column LOW (others HIGH)
;   2) Read rows (RB0..RB3). A pressed key pulls its row LOW.
;   3) Decode (row, column) into a key code in W.
;
; Return (W):
;   0..9 digits, 10..13 A..D, 14='*', 15='#', 0xFF = none
; =========================================================
KEYPAD_SCAN:
    ; ---- Column 1: RB4 LOW ----
    movlw   0b11100000
    call    _KP_SET_COLS
    call    _KP_READ_ROW
    movwf   TEMP_RAW
    movlw   KP_KEY_NONE
    xorwf   TEMP_RAW, W
    btfss   STATUS, Z_BIT
    goto    _KP_DECODE_COL1

    ; ---- Column 2: RB5 LOW ----
    movlw   0b11010000
    call    _KP_SET_COLS
    call    _KP_READ_ROW
    movwf   TEMP_RAW
    movlw   KP_KEY_NONE
    xorwf   TEMP_RAW, W
    btfss   STATUS, Z_BIT
    goto    _KP_DECODE_COL2

    ; ---- Column 3: RB6 LOW ----
    movlw   0b10110000
    call    _KP_SET_COLS
    call    _KP_READ_ROW
    movwf   TEMP_RAW
    movlw   KP_KEY_NONE
    xorwf   TEMP_RAW, W
    btfss   STATUS, Z_BIT
    goto    _KP_DECODE_COL3

    ; ---- Column 4: RB7 LOW ----
    movlw   0b01110000
    call    _KP_SET_COLS
    call    _KP_READ_ROW
    movwf   TEMP_RAW
    movlw   KP_KEY_NONE
    xorwf   TEMP_RAW, W
    btfss   STATUS, Z_BIT
    goto    _KP_DECODE_COL4

    ; no key detected on any column
    movlw   KP_KEY_NONE
    return

; ---------------------------------------------------------
; _KP_SET_COLS
; Input : W = new column pattern for RB4..RB7
; Action: preserve RB0..RB3, update RB4..RB7
; ---------------------------------------------------------
_KP_SET_COLS:
    banksel PORTB
    movwf   TEMP_WORK
    movf    PORTB, W
    andlw   0b00001111          ; keep rows unchanged
    iorwf   TEMP_WORK, W        ; apply new columns
    movwf   PORTB
    nop                         ; short settle delay
    nop
    return

; ---------------------------------------------------------
; _KP_READ_ROW
; Reads RB0..RB3 and returns row index in W if any row is LOW.
; Return:
;   W = 0..3 row number, or KP_KEY_NONE if none pressed
; ---------------------------------------------------------
_KP_READ_ROW:
    banksel PORTB
    movf    PORTB, W
    andlw   0b00001111
    xorlw   0b00001111
    btfsc   STATUS, Z_BIT
    goto    _KP_NO_ROW

    btfss   PORTB, 0
    goto    _KP_ROW0
    btfss   PORTB, 1
    goto    _KP_ROW1
    btfss   PORTB, 2
    goto    _KP_ROW2
    btfss   PORTB, 3
    goto    _KP_ROW3

_KP_NO_ROW:
    movlw   KP_KEY_NONE
    return
_KP_ROW0: movlw 0
          return
_KP_ROW1: movlw 1
          return
_KP_ROW2: movlw 2
          return
_KP_ROW3: movlw 3
          return

; ---------------------------------------------------------
; Key mapping (standard 4x4 keypad)
;   Col1: 1 4 7 *
;   Col2: 2 5 8 0
;   Col3: 3 6 9 #
;   Col4: A B C D
; TEMP_RAW holds row index 0..3 when pressed.
; ---------------------------------------------------------

; Col1: 1,4,7,*
_KP_DECODE_COL1:
    movf    TEMP_RAW, W
    xorlw   0
    btfsc   STATUS, Z_BIT
    goto    _RET_1
    movf    TEMP_RAW, W
    xorlw   1
    btfsc   STATUS, Z_BIT
    goto    _RET_4
    movf    TEMP_RAW, W
    xorlw   2
    btfsc   STATUS, Z_BIT
    goto    _RET_7
    goto    _RET_STAR

; Col2: 2,5,8,0
_KP_DECODE_COL2:
    movf    TEMP_RAW, W
    xorlw   0
    btfsc   STATUS, Z_BIT
    goto    _RET_2
    movf    TEMP_RAW, W
    xorlw   1
    btfsc   STATUS, Z_BIT
    goto    _RET_5
    movf    TEMP_RAW, W
    xorlw   2
    btfsc   STATUS, Z_BIT
    goto    _RET_8
    goto    _RET_0

; Col3: 3,6,9,#
_KP_DECODE_COL3:
    movf    TEMP_RAW, W
    xorlw   0
    btfsc   STATUS, Z_BIT
    goto    _RET_3
    movf    TEMP_RAW, W
    xorlw   1
    btfsc   STATUS, Z_BIT
    goto    _RET_6
    movf    TEMP_RAW, W
    xorlw   2
    btfsc   STATUS, Z_BIT
    goto    _RET_9
    goto    _RET_HASH

; Col4: A,B,C,D
_KP_DECODE_COL4:
    movf    TEMP_RAW, W
    xorlw   0
    btfsc   STATUS, Z_BIT
    goto    _RET_A
    movf    TEMP_RAW, W
    xorlw   1
    btfsc   STATUS, Z_BIT
    goto    _RET_B
    movf    TEMP_RAW, W
    xorlw   2
    btfsc   STATUS, Z_BIT
    goto    _RET_C
    goto    _RET_D

; ---------------------------------------------------------
; Key-code return stubs
; ---------------------------------------------------------
_RET_0:     movlw 0
            return
_RET_1:     movlw 1
            return
_RET_2:     movlw 2
            return
_RET_3:     movlw 3
            return
_RET_4:     movlw 4
            return
_RET_5:     movlw 5
            return
_RET_6:     movlw 6
            return
_RET_7:     movlw 7
            return
_RET_8:     movlw 8
            return
_RET_9:     movlw 9
            return
_RET_A:     movlw 10
            return
_RET_B:     movlw 11
            return
_RET_C:     movlw 12
            return
_RET_D:     movlw 13
            return
_RET_STAR:  movlw 14
            return
_RET_HASH:  movlw 15
            return

; =========================================================
; KEYPAD_TASK
; High-level keypad handler:
;   - Optionally consumes KP_INT_FLAG (if RB0/INT used)
;   - Debounces by ignoring repeat reads while a key is held
;   - Runs a state machine to collect and validate the setpoint
;   - On commit (#): writes DES_TEMP_H and DES_TEMP_L
; =========================================================
KEYPAD_TASK:
    ; Optional: clear interrupt flag (if ISR sets KP_INT_FLAG)
    banksel KP_INT_FLAG
    movf    KP_INT_FLAG, F
    btfsc   STATUS, Z_BIT
    goto    _KP_SCAN
    clrf    KP_INT_FLAG

_KP_SCAN:
    ; Scan keypad and keep result in TEMP_RAW
    call    KEYPAD_SCAN
    movwf   TEMP_RAW

    ; No key pressed => release "held" flag and exit
    movlw   KP_KEY_NONE
    xorwf   TEMP_RAW, W
    btfsc   STATUS, Z_BIT
    goto    _KP_NO_KEY

    ; If key is still held, ignore repeats (simple de-bounce)
    banksel KEY_FLAGS
    btfsc   KEY_FLAGS, KEY_HELD_BIT
    return
    bsf     KEY_FLAGS, KEY_HELD_BIT

    ; Dispatch based on current state
    banksel KEY_STATE
    movf    KEY_STATE, W
    btfsc   STATUS, Z_BIT
    goto    _KP_IDLE

    movf    KEY_STATE, W
    xorlw   KP_STATE_INT
    btfsc   STATUS, Z_BIT
    goto    _KP_INT

    movf    KEY_STATE, W
    xorlw   KP_STATE_FRAC
    btfsc   STATUS, Z_BIT
    goto    _KP_FRAC
    return

_KP_NO_KEY:
    banksel KEY_FLAGS
    bcf     KEY_FLAGS, KEY_HELD_BIT
    return

; ---------------------------------------------------------
; IDLE: wait for 'A' to start entry
; ---------------------------------------------------------
_KP_IDLE:
    movf    TEMP_RAW, W
    xorlw   KP_KEY_A
    btfss   STATUS, Z_BIT
    return

    movlw   KP_STATE_INT
    banksel KEY_STATE
    movwf   KEY_STATE

    ; clear buffers for new entry
    movlw   0xFF
    movwf   KEY_BUFFER0
    movwf   KEY_BUFFER1
    movwf   KEY_BUFFER2
    return

; ---------------------------------------------------------
; INT: collect two integer digits, allow '*' for fraction, '#' to commit
; ---------------------------------------------------------
_KP_INT:
    ; Commit requested?
    movf    TEMP_RAW, W
    xorlw   KP_KEY_HASH
    btfsc   STATUS, Z_BIT
    goto    _KP_COMMIT

    ; Switch to fractional entry?
    movf    TEMP_RAW, W
    xorlw   KP_KEY_STAR
    btfsc   STATUS, Z_BIT
    goto    _KP_GO_FRAC

    ; Restart entry if 'A' pressed again
    movf    TEMP_RAW, W
    xorlw   KP_KEY_A
    btfsc   STATUS, Z_BIT
    goto    _KP_RESTART

    ; Accept digits only (0..9)
    movf    TEMP_RAW, W
    sublw   9
    btfss   STATUS, C_BIT
    return

    ; Store first digit then second digit
    banksel KEY_BUFFER0
    movf    KEY_BUFFER0, W
    xorlw   0xFF
    btfsc   STATUS, Z_BIT
    goto    _STORE_D1

    movf    KEY_BUFFER1, W
    xorlw   0xFF
    btfsc   STATUS, Z_BIT
    goto    _STORE_D2
    return

_STORE_D1:
    banksel TEMP_RAW
    movf    TEMP_RAW, W
    banksel KEY_BUFFER0
    movwf   KEY_BUFFER0
    return

_STORE_D2:
    banksel TEMP_RAW
    movf    TEMP_RAW, W
    banksel KEY_BUFFER1
    movwf   KEY_BUFFER1
    return

; ---------------------------------------------------------
; Enter fractional mode only after at least the first digit exists
; ---------------------------------------------------------
_KP_GO_FRAC:
    banksel KEY_BUFFER0
    movf    KEY_BUFFER0, W
    xorlw   0xFF
    btfsc   STATUS, Z_BIT
    return

    movlw   KP_STATE_FRAC
    banksel KEY_STATE
    movwf   KEY_STATE

    ; clear fractional buffer (0xFF = not entered yet)
    movlw   0xFF
    movwf   KEY_BUFFER2
    return

; ---------------------------------------------------------
; FRAC: accept one fractional digit (0..9), '#' commit, 'A' restart
; ---------------------------------------------------------
_KP_FRAC:
    movf    TEMP_RAW, W
    xorlw   KP_KEY_HASH
    btfsc   STATUS, Z_BIT
    goto    _KP_COMMIT

    movf    TEMP_RAW, W
    xorlw   KP_KEY_A
    btfsc   STATUS, Z_BIT
    goto    _KP_RESTART

    ; digits only
    movf    TEMP_RAW, W
    sublw   9
    btfss   STATUS, C_BIT
    return

    ; store fractional digit only once
    banksel KEY_BUFFER2
    movf    KEY_BUFFER2, W
    xorlw   0xFF
    btfss   STATUS, Z_BIT
    return

    banksel TEMP_RAW
    movf    TEMP_RAW, W
    banksel KEY_BUFFER2
    movwf   KEY_BUFFER2
    return

; ---------------------------------------------------------
; Restart entry: go back to integer entry and clear buffers
; ---------------------------------------------------------
_KP_RESTART:
    movlw   KP_STATE_INT
    banksel KEY_STATE
    movwf   KEY_STATE
    movlw   0xFF
    movwf   KEY_BUFFER0
    movwf   KEY_BUFFER1
    movwf   KEY_BUFFER2
    return

; ---------------------------------------------------------
; Commit setpoint:
; Validation rules:
;   - Must have two integer digits (D1 and D2)
;   - D1 must be 1..5  (10..50)
;   - If D1=5 then D2 must be 0 and fraction must be 0 (max 50.0)
;   - If fraction not entered => assume 0
; On success:
;   - DES_TEMP_H = 10*D1 + D2
;   - DES_TEMP_L = fraction digit
; ---------------------------------------------------------
_KP_COMMIT:
    ; Require D1 and D2 to exist
    banksel KEY_BUFFER0
    movf    KEY_BUFFER0, W
    xorlw   0xFF
    btfsc   STATUS, Z_BIT
    goto    _KP_REJECT

    banksel KEY_BUFFER1
    movf    KEY_BUFFER1, W
    xorlw   0xFF
    btfsc   STATUS, Z_BIT
    goto    _KP_REJECT

    ; If fraction missing => treat as 0
    banksel KEY_BUFFER2
    movf    KEY_BUFFER2, W
    xorlw   0xFF
    btfss   STATUS, Z_BIT
    goto    _HAVE_FRAC
    clrf    KEY_BUFFER2

_HAVE_FRAC:
    ; D1 cannot be 0
    banksel KEY_BUFFER0
    movf    KEY_BUFFER0, F
    btfsc   STATUS, Z_BIT
    goto    _KP_REJECT

    ; D1 must be <= 5
    movf    KEY_BUFFER0, W
    sublw   5
    btfss   STATUS, C_BIT
    goto    _KP_REJECT

    ; If D1 == 5 => enforce 50.0 only (D2=0, frac=0)
    movf    KEY_BUFFER0, W
    xorlw   5
    btfss   STATUS, Z_BIT
    goto    _COMPUTE_DES

    banksel KEY_BUFFER1
    movf    KEY_BUFFER1, F
    btfss   STATUS, Z_BIT
    goto    _KP_REJECT
    banksel KEY_BUFFER2
    movf    KEY_BUFFER2, F
    btfss   STATUS, Z_BIT
    goto    _KP_REJECT

_COMPUTE_DES:
    ; Compute DES_TEMP_H = (10 * D1) + D2
    banksel DES_TEMP_H
    clrf    DES_TEMP_H

    banksel KEY_BUFFER0
    movf    KEY_BUFFER0, W
    movwf   TEMP_WORK           ; TEMP_WORK = D1 (loop count)

_MUL10_LOOP:
    banksel TEMP_WORK
    movf    TEMP_WORK, F
    btfsc   STATUS, Z_BIT
    goto    _MUL10_DONE
    movlw   10
    banksel DES_TEMP_H
    addwf   DES_TEMP_H, F
    banksel TEMP_WORK
    decf    TEMP_WORK, F
    goto    _MUL10_LOOP

_MUL10_DONE:
    banksel KEY_BUFFER1
    movf    KEY_BUFFER1, W
    banksel DES_TEMP_H
    addwf   DES_TEMP_H, F       ; add D2

    ; Write fractional digit: DES_TEMP_L = KEY_BUFFER2
    banksel KEY_BUFFER2
    movf    KEY_BUFFER2, W
    banksel DES_TEMP_L
    movwf   DES_TEMP_L

    ; Debug/trace flag: indicates a successful commit event occurred
    banksel KP_INT_FLAG
    movlw   1
    movwf   KP_INT_FLAG

    ; Reset state machine back to IDLE
    banksel KEY_STATE
    clrf    KEY_STATE
    movlw   0xFF
    movwf   KEY_BUFFER0
    movwf   KEY_BUFFER1
    movwf   KEY_BUFFER2
    return

; ---------------------------------------------------------
; Reject entry and reset state/buffers
; ---------------------------------------------------------
_KP_REJECT:
    banksel KEY_STATE
    clrf    KEY_STATE
    movlw   0xFF
    movwf   KEY_BUFFER0
    movwf   KEY_BUFFER1
    movwf   KEY_BUFFER2
    return

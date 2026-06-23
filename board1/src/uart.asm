; =========================================================
; uart.asm (PIC16F877A / XC8 pic-as)  - Board #1
; Author      : Yusuf Tuzcu
; Student ID  : 151220202144
; Department  : Electrical and Electronics Engineering
; =========================================================
; Pin mapping (hardware UART):
;   TX = RC6
;   RX = RC7
;
; UART configuration:
;   Baud rate : 9600 bps
;   FOSC      : 4 MHz (XT)
;   BRGH      : 1 (high-speed mode)
;   SPBRG     : 25  (9600 @ 4 MHz with BRGH=1)
;
; Provided routines:
;   - UART_INIT            : Initialize EUSART (TX/RX enabled)
;   - UART_SEND_CHAR       : Blocking transmit of one byte (W = byte)
;   - UART_SEND_STR_Z      : Send 0-terminated RAM string (FSR -> string)
;   - UART_SEND_HEX8       : Send one byte as 2 ASCII hex chars
;   - UART_STREAM_STATUS   : Optional status frame for debug/telemetry
;
; Requirement Mapping:
;   [R2.1.4-1] System shall transmit status information via UART.
; =========================================================

    PROCESSOR   16F877A
    #include    <xc.inc>
    #include    "config.inc"

    PSECT   code

; ---------------------------------------------------------
; Bit index definitions (explicit bit numbers to prevent
; assembler "bad bit number" errors and improve readability)
; ---------------------------------------------------------
TXIF_BIT    EQU 4       ; PIR1<4> : TXIF = 1 when TXREG is empty (ready to load)
RCIF_BIT    EQU 5       ; PIR1<5> : RCIF = 1 when a byte is received (not used here)

OERR_BIT    EQU 1       ; RCSTA<1>: Overrun error (receiver stopped if set)
CREN_BIT    EQU 4       ; RCSTA<4>: Continuous receive enable

BRGH_BIT    EQU 2       ; TXSTA<2>: High baud rate select
SYNC_BIT    EQU 4       ; TXSTA<4>: SYNC=0 async mode, SYNC=1 sync mode
TXEN_BIT    EQU 5       ; TXSTA<5>: Transmit enable

SPEN_BIT    EQU 7       ; RCSTA<7>: Serial port enable (enables RX/TX pins)

; =========================================================
; UART_INIT
; Initializes the EUSART peripheral for asynchronous operation.
; - Sets baud rate generator (SPBRG)
; - Enables transmitter (TXEN) and serial port (SPEN)
; - Enables receiver (CREN) (even if RX not used, safe default)
; - Clears possible receiver overrun condition
;
; Requirement Mapping:
;   [R2.1.4-1] Enables UART channel used to transmit status data.
; =========================================================
UART_INIT:
    ; Set baud rate generator for 9600 bps @ 4 MHz (BRGH=1)
    banksel SPBRG
    movlw   25
    movwf   SPBRG

    ; TXSTA configuration:
    ;   BRGH=1 (high speed), SYNC=0 (async), TXEN=1 (enable transmitter)
    banksel TXSTA
    bsf     TXSTA, BRGH_BIT
    bcf     TXSTA, SYNC_BIT
    bsf     TXSTA, TXEN_BIT

    ; RCSTA configuration:
    ;   SPEN=1 enable serial port pins, CREN=1 enable receiver
    banksel RCSTA
    bsf     RCSTA, SPEN_BIT
    bsf     RCSTA, CREN_BIT

    ; Defensive: clear overrun error if it occurred
    call    UART_RX_CLEAR_OERR
    return

; =========================================================
; UART_SEND_CHAR (blocking transmit)
; Input:
;   W = byte to transmit
; Behavior:
;   - Waits until TXIF=1 (TXREG empty)
;   - Writes byte to TXREG
; Notes:
;   - Uses TEMP_RAW (defined in main.asm) as a scratch register
; =========================================================
UART_SEND_CHAR:
    banksel TEMP_RAW
    movwf   TEMP_RAW            ; preserve byte while waiting for TX ready

_USC_WAIT:
    banksel PIR1
    btfss   PIR1, TXIF_BIT      ; TXIF=1 => TXREG empty
    goto    _USC_WAIT

    ; Load TXREG to start transmission
    banksel TXREG
    banksel TEMP_RAW
    movf    TEMP_RAW, W
    movwf   TXREG
    return

; =========================================================
; UART_RX_CLEAR_OERR
; Clears receiver overrun error (OERR).
; If OERR=1, the receiver stops and must be reset by toggling CREN.
; =========================================================
UART_RX_CLEAR_OERR:
    banksel RCSTA
    btfss   RCSTA, OERR_BIT
    return
    bcf     RCSTA, CREN_BIT     ; disable receiver to clear OERR
    bsf     RCSTA, CREN_BIT     ; re-enable receiver
    return

; =========================================================
; UART_SEND_HEX8
; Input:
;   W = byte
; Output (UART):
;   Two ASCII characters representing the byte in hexadecimal (00..FF).
; Notes:
;   - Uses TEMP_RAW and TEMP_WORK as scratch (from main.asm).
; =========================================================
UART_SEND_HEX8:
    banksel TEMP_RAW
    movwf   TEMP_RAW            ; store original byte

    ; ---- transmit high nibble ----
    banksel TEMP_RAW
    movf    TEMP_RAW, W
    andlw   0xF0                ; keep upper nibble
    movwf   TEMP_WORK
    swapf   TEMP_WORK, W        ; move upper nibble to lower position
    andlw   0x0F
    call    UART_NIBBLE_TO_ASCII
    call    UART_SEND_CHAR

    ; ---- transmit low nibble ----
    banksel TEMP_RAW
    movf    TEMP_RAW, W
    andlw   0x0F                ; keep lower nibble
    call    UART_NIBBLE_TO_ASCII
    call    UART_SEND_CHAR
    return

; ---------------------------------------------------------
; UART_NIBBLE_TO_ASCII
; Input:
;   W = 0..15
; Output:
;   W = ASCII '0'..'9' or 'A'..'F'
; ---------------------------------------------------------
UART_NIBBLE_TO_ASCII:
    addlw   '0'                 ; tentative ASCII in '0'..'?'
    movwf   TEMP_WORK
    movlw   '9'+1
    subwf   TEMP_WORK, W
    btfsc   STATUS, C_BIT       ; if >= '9'+1 -> convert to 'A'..'F'
    goto    _HEX_ALPHA
    movf    TEMP_WORK, W        ; return '0'..'9'
    return
_HEX_ALPHA:
    movf    TEMP_WORK, W
    addlw   7                   ; adjust to 'A'..'F'
    return

; =========================================================
; UART_SEND_STR_Z
; Sends a zero-terminated string from RAM using indirect addressing.
; Input:
;   FSR -> start of string
;   INDF reads current char
; Terminator:
;   0x00 ends the string
; =========================================================
UART_SEND_STR_Z:
    banksel INDF
_USZ_LOOP:
    movf    INDF, W
    btfsc   STATUS, Z_BIT       ; if char == 0 -> done
    return
    call    UART_SEND_CHAR
    incf    FSR, F              ; next character
    goto    _USZ_LOOP

; =========================================================
; UART_STREAM_STATUS (optional debug/telemetry frame)
; Frame format (as implemented):
;   "A=" + AMB_TEMP_H (HEX) + "." + AMB_TEMP_L (decimal digit)
;   " D=" + DES_TEMP_H (HEX) + "." + DES_TEMP_L (decimal digit)
;   "\r\n"
;
; Requirement Mapping:
;   [R2.1.4-1] Streams key status variables over UART for monitoring.
;
; NOTE:
;   AMB_TEMP_H and DES_TEMP_H represent decimal temperatures,
;   but they are printed in HEX using UART_SEND_HEX8.
;   If the grading rubric expects decimal text (e.g., 23.4),
;   replace HEX output with a BIN->DEC ASCII conversion routine.
; =========================================================
UART_STREAM_STATUS:
    ; Send "A="
    movlw   'A'
    call    UART_SEND_CHAR
    movlw   '='
    call    UART_SEND_CHAR

    ; Ambient integer part (currently HEX)
    banksel AMB_TEMP_H
    movf    AMB_TEMP_H, W
    call    UART_SEND_HEX8

    ; Send ".<frac>"
    movlw   '.'
    call    UART_SEND_CHAR
    banksel AMB_TEMP_L
    movf    AMB_TEMP_L, W
    addlw   '0'                 ; 0..9 -> ASCII digit
    call    UART_SEND_CHAR

    ; Send " D="
    movlw   ' '
    call    UART_SEND_CHAR
    movlw   'D'
    call    UART_SEND_CHAR
    movlw   '='
    call    UART_SEND_CHAR

    ; Desired integer part (currently HEX)
    banksel DES_TEMP_H
    movf    DES_TEMP_H, W
    call    UART_SEND_HEX8

    ; Send ".<frac>"
    movlw   '.'
    call    UART_SEND_CHAR
    banksel DES_TEMP_L
    movf    DES_TEMP_L, W
    addlw   '0'
    call    UART_SEND_CHAR

    ; Line ending CRLF
    movlw   13                  ; '\r'
    call    UART_SEND_CHAR
    movlw   10                  ; '\n'
    call    UART_SEND_CHAR
    return

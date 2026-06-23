; ============================================
; i2c.asm - Board 2 I2C Master Driver
; ============================================

; --------------------------------------------
; I2C_INIT
; --------------------------------------------
I2C_INIT:
    BANKSEL TRISC
    BSF     TRISC, 3
    BSF     TRISC, 4
    MOVLW   0x80		
    MOVWF   SSPSTAT		; 1000 0000 SMP=1
    CLRF    SSPCON2
    MOVLW   9
    MOVWF   SSPADD		; SCL = 100kHz
    BCF     STATUS, 5
    MOVLW   0x28
    MOVWF   SSPCON		;I2C configured to Master mode 
    RETURN

; --------------------------------------------
; I2C_WAIT
; --------------------------------------------
I2C_WAIT:
    BSF     STATUS, 5		;Bank 1
WAIT_RW:
    BTFSC   SSPSTAT, 2		;Read mode
    GOTO    WAIT_RW
    MOVF    SSPCON2, W		
    ANDLW   0x1F
    BTFSS   STATUS, 2
    GOTO    WAIT_RW
    BCF	    STATUS, 5
    RETURN

; --------------------------------------------
; I2C_START
; --------------------------------------------
I2CSTART:
    CALL    I2C_WAIT
    BSF	    STATUS, 5
    BSF     SSPCON2, 0		;SEN=1 START
    BCF     STATUS, 5
    RETURN

; --------------------------------------------
; I2C_RESTART
; --------------------------------------------
I2C_RESTART:
    CALL    I2C_WAIT
    BSF     STATUS, 5
    BSF     SSPCON2, 1		;RSEN=1 Repeated START
    BCF     STATUS, 5
    RETURN

; --------------------------------------------
; I2C_STOP
; --------------------------------------------
I2CSTOP:
    CALL    I2C_WAIT
    BSF     STATUS, 5
    BSF     SSPCON2, 2		;PEN=1
    BCF     STATUS, 5
    RETURN

; --------------------------------------------
; I2C_WRITE
; --------------------------------------------
I2C_WRITE:
    CALL    I2C_WAIT
    MOVWF   SSPBUF
    CALL    I2C_WAIT
    BSF     STATUS, 5
    BTFSC   SSPCON2, 6		;ACKSTAT
    GOTO    WRITE_NACK
    BCF     STATUS, 0
    GOTO    WRITE_EXIT
WRITE_NACK:
    BSF     STATUS, 0		;C=1
WRITE_EXIT:
    BCF     STATUS, 5
    RETURN
    
; --------------------------------------------
; I2C_READ
; --------------------------------------------
I2CREAD:
    MOVWF   TEMP_WORK
    CALL    I2C_WAIT
    BSF     STATUS, 5
    BSF     SSPCON2, 3		;RCEN=1
    BCF     STATUS, 5
    CALL    I2C_WAIT
    MOVF    SSPBUF, W
    MOVWF   UART_TX_BYTE
    CALL    I2C_WAIT
    BSF     STATUS, 5
    BTFSC   TEMP_WORK, 0
    GOTO    SEND_NAK_BIT
    BCF     SSPCON2, 5
    GOTO    START_ACK
SEND_NAK_BIT:
    BSF     SSPCON2, 5
START_ACK:
    BSF     SSPCON2, 4
    BCF     STATUS, 5
    MOVF    UART_TX_BYTE, W
    RETURN
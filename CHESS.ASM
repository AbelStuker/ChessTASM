; -------------------------------------------------------------------
; 80386
; 32-bit x86 assembly language
; TASM
; ---------∏----------------------------------------------------------

IDEAL
P386
MODEL FLAT, C
ASSUME cs:_TEXT,ds:FLAT,es:FLAT,fs:FLAT,gs:FLAT

INCLUDE "CHESS.INC"

SCREENWIDTH EQU 320
SCREENHEIGHT EQU 200
CELLS EQU 8
CELLDIMENSION EQU (SCREENHEIGHT / CELLS)

; alle font gedoe gepikt van Robbe :)
FONTCHAR_WIDTH EQU 8
FONTCHAR_HEIGHT EQU 16 
FONTCHAR_SIZE EQU 16
FONTCHAR_COUNT EQU 128
FONTFILE_SIZE EQU (FONTCHAR_SIZE * FONTCHAR_COUNT)

; -------------------------------------------------------------------
; CODE
; -------------------------------------------------------------------
CODESEG


PROC setupVideo
	USES eax
	mov ax,13h
	
	int 10h
	ret
ENDP setupVideo
;-----------------------------------------------------------------------?
PROC unsetupVideo
	USES eax
	mov ax,03h
	
	int 10h
	ret
ENDP unsetupVideo
;-----------------------------------------------------------------------?



PROC displayString
    ARG @@row:DWORD, @@column:DWORD, @@offset:DWORD
    USES EAX, EBX, EDX
    MOV EDX, [@@row]    ; row in EDX
    MOV EBX, [@@column] ; column in EBX
    MOV AH, 02H
    SHL EDX, 08H
    MOV DL, BL
    MOV BH, 0
    INT 10H
    ; set cursor position
    ; row in DH (00H is top)
    ; column in DL (00H is left)
    ; page number in BH
    ; raise interrupt
    ; write string to standard output
    MOV AH, 09H
    MOV EDX, [@@offset] ; offset of ’$’-terminated string in EDX
    INT 21H             ; raise interrupt
    RET
ENDP displayString



proc drawHorizontalLine
    uses eax, edx, ecx
    arg @@line:DWORD
    ; feature suggestion: line width
    xor ecx, ecx    ; clear ecx value
    mov eax, SCREENWIDTH
    mul [@@line]
    mov ecx, SCREENWIDTH
    @@drawHLine:
        mov [framebuffer + eax + ecx - 1], 0Fh
        loop @@drawHLine
    ret
endp drawHorizontalLine
    
proc drawVerticalLine
    uses ebx, edx, eax
    arg @@vline:DWORD
    ; feature suggestion: line width
    xor ecx, ecx    ; clear ecx value
    mov ebx, [@@vline]
    mov eax, SCREENHEIGHT-1
    mov edx, SCREENWIDTH
    mul edx
    @@drawVLine:
        mov [framebuffer + eax + ebx - 1], 0Fh
        sub eax, SCREENWIDTH
        cmp eax, 0
        jge @@drawVLine
    ret

endp drawVerticalLine
        

proc drawBoard
    uses edx, ecx
    xor edx, edx        ; edx = 0 (initinial counter value)
    xor ecx, ecx        ; ecx = 0 (initinial counter value)

    @@drawRow:
        call drawCell, ecx, edx
        add ecx, 1
        cmp ecx, CELLS
        jl @@drawRow

    @@newRow:
        xor ecx, ecx
        add edx, 1
        cmp edx, CELLS
        jl @@drawRow

    ret
    
endp drawBoard

proc drawCell
    uses eax, edx, ecx
    arg @@xPos:DWORD, @@yPos:DWORD

    mov eax, [@@yPos]
    mov edx, CELLDIMENSION
    mul edx
    mov edx, SCREENWIDTH
    mul edx                 
    mov ebx, eax            ; ebx contains offset of first pixel of the line containing the top-left corner of the cell
    mov eax, [@@xPos] 
    mov edx, CELLDIMENSION
    mul edx                 ; eax contains the x-coordinate of the top-left corner of the cell
    add ebx, eax            ; (ebx = ebx + eax) containing the offset off the top-left corner pixel of the cell

    call determineColor, [@@xPos], [@@yPos]     ; color in al

    xor edx, edx    
    @@verticalLoop:
        mov ecx, CELLDIMENSION

        @@horizontalLoop:
            mov [framebuffer + ebx + ecx - 1], al
            loop @@horizontalLoop

        inc edx
        add ebx, SCREENWIDTH        ; add screenwidth to ebx (offset) to jump to the leftmost pixel at the next line
        cmp edx, CELLDIMENSION
        jl @@verticalLoop

    ret

endp drawCell

proc determineColor
    arg @@xPos:DWORD, @@yPos:DWORD
    ; returns eax

    mov eax, [@@xPos]
    add eax, [@@yPos]       ; xPos + yPos
    shr eax, 1              ; test whether sum is even: bitshift 1 position to the right
    jc @@unevenColor        ; if carry flag (CF) is 1, then the sum was uneven

    @@evenColor:
        mov al, [whiteColor]
        jmp @@return

    @@unevenColor:
        mov al, [blackColor]

    @@return:
        ret

endp determineColor


PROC transferFrame
	USES ecx, edi, esi
	mov edi, 0A0000h
	mov esi, offset framebuffer
	mov ecx, 64000/4
	rep movsd
	ret
ENDP transferFrame

; Terminate the program.
PROC terminateProcess
	USES eax
	call unsetupVideo
	mov	ax,04C00h
	int 21h
	ret
ENDP terminateProcess



;; FILE HANDLING --------

proc getFileHandle
    arg @@fileName:dword, @@accessMode:dword
    uses ebx, ecx, edx

    xor eax, eax                ; clear the eax register (handle is stored only in ax)
    mov edx, [@@fileName]
    mov ecx, [@@accessMode]
    mov ah, 3Dh
    int 21h                     ; carry flag (CF) is set to 1 in case of error 
    ;; TODO: handle CF=1 (error case)
    ret
endp getFileHandle


; read bytes from a file and move them to @@data
proc readFile
    arg @@fileHandle:dword, @@dataBuffer:dword, @@byteCount:dword
    uses ebx, ecx, edx

    mov ah, 3Fh
    mov ebx, [@@fileHandle]     ; only 16 bits are read by interrupt, but since arguments are DWORDs we move the entire DWORD to eax
    mov ecx, [@@byteCount]
    mov edx, [@@dataBuffer]
    int 21h                     ; carry flag (CF) is set to 1 in case of error 
    ;; TODO: handle CF=1 (error case)
    ret
endp readFile

; close a file
proc closeFile
    arg @@fileHandle:dword
    uses eax, ebx

    mov ebx, [@@fileHandle]
    mov ah, 3Eh
    int 21h
    ret
endp closeFile

;;

proc loadPiece
    arg @@fileName:dword, @@dataBuffer:dword
    uses eax, ebx
    
    call getFileHandle, [@@fileName], 0
    mov ebx, eax
    call readFile, ebx, [@@dataBuffer], PIECE_SIZE
    call closeFile, ebx

    ret

endp loadPiece

proc loadPieces
    call loadPiece, offset pionFileName, offset pionArray
    call drawPiece, offset pionArray, 0, 0
    ret
endp loadPieces

proc drawPiece
    arg @@dataBuffer:dword, @@x_coord:dword, @@y_coord:dword
    uses eax, ebx, ecx, edx, edi

    mov edi, [@@dataBuffer]     ; edx contains address where bitmap starts
    mov ecx, 0
    @@y_loop:
        push ecx
        mov ecx, PIECE_WIDTH
        @@x_loop:
            push ecx
            mov cl, 7
            @@x_byte_loop:
                mov al, [byte ptr edi]  ; move value at addr in ebx to eax to perform calculations (check bit at position ecx)
                shr al, cl             ; bitshift MUST be CL or a constant, nothing else!
                and al, 1
                cmp al, 0
                je @@x_byte_continue
                call drawPixel, [@@x_coord], [@@y_coord], 0Fh

            @@x_byte_continue:
                inc [@@x_coord]
                dec cl
                cmp cl, 0
                jge @@x_byte_loop

            @@x_loop_continue:
                pop ecx
                sub ecx, 8
                inc edi
                cmp ecx, 0
                jle @@y_continue
                inc [@@x_coord]
                jmp @@x_loop

    @@y_continue:
        inc [@@y_coord]
        mov [@@x_coord], 0
        pop ecx
        inc ecx
        cmp ecx, PIECE_HEIGHT
        je @@return
        jmp @@y_loop

    @@return:
        ret
    
endp drawPiece

;; --------


proc loadFont
    uses eax
    call getFileHandle, offset fontfilename, 0
    mov edx, eax
    call readFile, edx, offset fontarray, FONTFILE_SIZE
    call closeFile, edx
endp loadFont

; Plots a sequence of character to the screen
proc drawString
    arg @@x_coord:dword, @@y_coord:dword, @@text:dword, @@color:dword
    uses eax, ebx

    mov ebx, [@@text]
    @@char_loop:
        cmp [byte ptr ebx], 0
        je @@end

        movzx eax, [byte ptr ebx] ; zero extend
        call drawCharacter, [@@x_coord], [@@y_coord], eax, [@@color]

        add [@@x_coord], FONTCHAR_WIDTH*2
        inc ebx
        jmp @@char_loop

@@end:
    ret
endp drawString

; draw a single character on the screen
proc drawCharacter
    arg @@x_coord:dword, @@y_coord:dword, @@char:dword, @@color:dword
    uses eax, ecx, edx, edi

    mov eax, FONTCHAR_SIZE
    mul [@@char]
    lea edi, [fontarray + eax]

    xor edx, edx
    @@yLoop:
        cmp edx, FONTCHAR_HEIGHT
        je @@end
        
        mov ecx, (FONTCHAR_WIDTH-1)
        @@xLoop:
            cmp ecx, 0
            jl @@xLoopEnd

            movzx eax, [byte ptr edi]
            shr eax, cl
            and eax, 1
            cmp eax, 1
            jne @@continue

            call drawPixel, [@@x_coord], [@@y_coord], [@@color]

            @@continue:
            inc [@@x_coord]
            dec ecx
            jmp @@xLoop

            @@xLoopEnd:
                inc [@@y_coord]
                inc edi
                inc edx
                sub [@@x_coord], FONTCHAR_WIDTH
                jmp @@yLoop

@@end:
    ret
endp drawCharacter

; draws a single pixel onto the screen 
proc drawPixel
    arg @@x_coord:dword, @@y_coord:dword, @@color:dword
    uses eax, ebx, edx

    mov eax, SCREENWIDTH
    mul [@@y_coord]                 ; multiply screenwidth with y-coordinate -> first pixel address of line in eax
    add eax, [@@x_coord]            ; add x-coordinate to first pixel address of line to get complete coordinate address in eax

    lea ebx, [framebuffer + eax]
    mov edx, [@@color]

    ; Initially, we made a mistake by moving edx to [ebx], which resulted in horizontally surrounding pixels turning black.
    ; The problem was that we moved the entire DWORD color (edx), overwriting 32 bits instead of only 8 (for a single pixel).
    ; Solution: 
    mov [ebx], dl

    ret
endp

PROC main
	sti
	cld

	push ds
	pop	es 

	; set video mode, init registers
    call setupVideo

    call drawBoard
    call loadPieces

    ;mov eax, [dword ptr string1]
    ;call drawString, 50, 50, eax, 3
	
    @@animation_loop:

        ; TODO frame must be cleared if necessary
        ; TODO something with VBlank
        call transferFrame
        
        ; check for early termination
        xor al, al
        mov	ah, 01h
        int	16h
        cmp	al, 1Bh
        je	@@finish
        loop @@animation_loop
    

    @@finish:
        call terminateProcess



ENDP main



; -------------------------------------------------------------------
; DATA
; -------------------------------------------------------------------
DATASEG
    string0 db "TestString", 13, 10, '$'
    string1 db "Another Thing", 13, 10, '$'
    poisonPixel dd 8
    framebuffer db 64000 dup (0)
    selectedcell dd 1
    leftcellvisible dw 0
    rightcellvisible dw 0
    fontfilename db "GUI\FONT.BIN", 0
    fontarray db FONTFILE_SIZE dup (?)
    
    pionFileName db "bitmaps/king.bin", 0
    pionArray dd PIECE_SIZE dup (?)

    whiteColor db 35h
    blackColor db 37h
    

; -------------------------------------------------------------------
; STACK
; -------------------------------------------------------------------
STACK 100h

END main

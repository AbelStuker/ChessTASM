; -------------------------------------------------------------------
; 80386
; 32-bit x86 assembly language
; TASM
; ---------∏----------------------------------------------------------

IDEAL
P386
MODEL FLAT, C
ASSUME cs:_TEXT,ds:FLAT,es:FLAT,fs:FLAT,gs:FLAT

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
    mov ebx, eax
    mov eax, [@@xPos]
    mov edx, CELLDIMENSION
    mul edx
    add ebx, eax

    call determineColor, [@@xPos], [@@yPos]     ; color in al
    mov ecx, CELLDIMENSION
    mov edx, 0
    
    @@horizontalLoop:
    
        mov [framebuffer + ebx + ecx - 1], al
        loop @@horizontalLoop
    
    @@verticalLoop:
        mov ecx, CELLDIMENSION
        inc edx
        add ebx, SCREENWIDTH
        cmp edx, CELLDIMENSION
        jl @@horizontalLoop

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
    mul [@@y_coord]
    add eax, [@@x_coord]

    lea ebx, [framebuffer + eax*4]
    mov edx, [@@color]
    mov [ebx], edx

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






; ;; Draws one pixel at a certain coordinate in the @@color color
; proc drawPixel
;     arg @@x_coord:dword, @@y_coord:dword, @@color:dword
;     uses eax, ebx, edx

;     mov eax, 800                    ; screen width
;     mul [@@y_coord]
;     add eax, [@@x_coord]
;     lea ebx, [framebuffer + eax*4]
;     mov edx, [@@color]
;     mov [ebx], edx

;     ret
; endp drawPixel





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

    whiteColor db 35h
    blackColor db 37h
    

; -------------------------------------------------------------------
; STACK
; -------------------------------------------------------------------
STACK 100h

END main

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
INCLUDE "MOUSE.INC"


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
	USES eax, ecx, edi, esi

    ; We must save the color of the pixel at the mouse position, because it will be overwritten by the mouse pointer.
    ; We don't want the framebuffer to contain the path the mouse pointer has taken, so we will replace the mouse pointer
    ;   with the original pixel color afterwards.
    call offsetFromCoordinate, [lastMouseX], [lastMouseY]       ; returns the offset of the mouse pointer in eax
    mov bl, [framebuffer + eax]                                 ; save color of pixel at mouse pointer in bl
    mov [framebuffer + eax], 0Fh                                ; overwrite pixel at mouse pointer with white color

    ; transfer frame buffer
	mov edi, VADDR
	mov esi, offset framebuffer
	mov ecx, 64000/4
	rep movsd

    ; restore color of pixel at mouse pointer
    mov [framebuffer + eax], bl


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
    call loadPiece, offset rookFileName, offset rookArray
    call loadPiece, offset knightFileName, offset knightArray
    call loadPiece, offset bishopFileName, offset bishopArray
    call loadPiece, offset queenFileName, offset queenArray
    call loadPiece, offset kingFileName, offset kingArray

    call drawPieces
    ret
endp loadPieces

proc drawPieces

    ; white pieces
    call drawPiece, offset pionArray, (CELLDIMENSION * 0), (CELLDIMENSION * 1), 0Fh
    call drawPiece, offset pionArray, (CELLDIMENSION * 1), (CELLDIMENSION * 1), 0Fh
    call drawPiece, offset pionArray, (CELLDIMENSION * 2), (CELLDIMENSION * 1), 0Fh
    call drawPiece, offset pionArray, (CELLDIMENSION * 3), (CELLDIMENSION * 1), 0Fh
    call drawPiece, offset pionArray, (CELLDIMENSION * 4), (CELLDIMENSION * 1), 0Fh
    call drawPiece, offset pionArray, (CELLDIMENSION * 5), (CELLDIMENSION * 1), 0Fh
    call drawPiece, offset pionArray, (CELLDIMENSION * 6), (CELLDIMENSION * 1), 0Fh
    call drawPiece, offset pionArray, (CELLDIMENSION * 7), (CELLDIMENSION * 1), 0Fh
    call drawPiece, offset rookArray, 0, 0, 0Fh
    call drawPiece, offset rookArray, (CELLDIMENSION * 7), 0, 0Fh
    call drawPiece, offset knightArray, (CELLDIMENSION * 1), 0, 0Fh
    call drawPiece, offset knightArray, (CELLDIMENSION * 6), 0, 0Fh
    call drawPiece, offset bishopArray, (CELLDIMENSION * 2), 0, 0Fh
    call drawPiece, offset bishopArray, (CELLDIMENSION * 5), 0, 0Fh
    call drawPiece, offset queenArray, (CELLDIMENSION * 3), 0, 0Fh
    call drawPiece, offset kingArray, (CELLDIMENSION * 4), 0, 0Fh

    ; black pieces
    call drawPiece, offset pionArray, (CELLDIMENSION * 0), (CELLDIMENSION * 6), 00h
    call drawPiece, offset pionArray, (CELLDIMENSION * 1), (CELLDIMENSION * 6), 00h
    call drawPiece, offset pionArray, (CELLDIMENSION * 2), (CELLDIMENSION * 6), 00h
    call drawPiece, offset pionArray, (CELLDIMENSION * 3), (CELLDIMENSION * 6), 00h
    call drawPiece, offset pionArray, (CELLDIMENSION * 4), (CELLDIMENSION * 6), 00h
    call drawPiece, offset pionArray, (CELLDIMENSION * 5), (CELLDIMENSION * 6), 00h
    call drawPiece, offset pionArray, (CELLDIMENSION * 6), (CELLDIMENSION * 6), 00h
    call drawPiece, offset pionArray, (CELLDIMENSION * 7), (CELLDIMENSION * 6), 00h
    call drawPiece, offset rookArray, 0, (CELLDIMENSION * 7), 00h
    call drawPiece, offset rookArray, (CELLDIMENSION * 7), (CELLDIMENSION * 7), 00h
    call drawPiece, offset knightArray, (CELLDIMENSION * 1), (CELLDIMENSION * 7), 00h
    call drawPiece, offset knightArray, (CELLDIMENSION * 6), (CELLDIMENSION * 7), 00h
    call drawPiece, offset bishopArray, (CELLDIMENSION * 2), (CELLDIMENSION * 7), 00h
    call drawPiece, offset bishopArray, (CELLDIMENSION * 5), (CELLDIMENSION * 7), 00h
    call drawPiece, offset queenArray, (CELLDIMENSION * 3), (CELLDIMENSION * 7), 00h
    call drawPiece, offset kingArray, (CELLDIMENSION * 4), (CELLDIMENSION * 7), 00h
    ret
endp drawPieces

proc drawPiece
    arg @@dataBuffer:dword, @@x:dword, @@y:dword, @@color:dword
    uses eax, ebx, ecx, edx, edi

    mov edi, [@@dataBuffer]     ; edx contains address where bitmap starts
    mov edx, 0
    @@bitmap_loop:
        mov eax, [dword ptr edi]
        mov ecx, 0
        @@dword_loop:
            push eax
            shr eax, cl
            and eax, 1
            cmp eax, 0
            je @@continue
            push edx
            xor edx, edx
            mov eax, ecx        ; move current index of dword_loop to eax
            mov ebx, 8
            div ebx             ; divide index by 8 : current byte offset (starting from right) in eax, current bit offset in byte (starting from right) in edx
            mov ebx, 7
            sub ebx, edx        ; (7 - byte offset from right) to get current bit starting from left instead of right of byte 
            push ebx
            mov ebx, 8
            mul ebx             ; multiply byte offset with 8 to get bit offset
            pop ebx
            add eax, ebx        ; total offset in eax = byte offset + bit offset (in byte)
            pop edx             ; restore edx (bits counted in buffer)
                                ; This does not correspond to the actual bit index, since we read each dword backwards due to little endian memory organisation.
            add eax, edx        ; In order to calculate the total offset, we add the current bit offset in the current dword (eax) to the offset where the current
            sub eax, ecx        ;   dword begins (i.e. the total amount of bits counted minus the amount of bits counted in the current dword: eax - ecx).
            mov ebx, PIECE_WIDTH
            push edx            ; store edx (byte in buffer index) because edx is used to store remainder after division
            xor edx, edx
            div ebx             ; y-index in eax, x-index in edx
            add edx, [@@x]
            add eax, [@@y]
            call drawPixel, edx, eax, [@@color]
            pop edx             ; restore edx
        @@continue:
            pop eax
            inc ecx
            inc edx
            cmp edx, PIECE_SIZE
            je @@return
            cmp ecx, 32
            jl @@dword_loop
        @@next_dword:
            add edi, 4
            jmp @@bitmap_loop


   ; mov edi, [@@dataBuffer]     ; edx contains address where bitmap starts
   ; mov ecx, 0
   ; @@y_loop:
   ;     push ecx
   ;     mov ecx, PIECE_WIDTH
   ;     @@x_loop:
   ;         push ecx
   ;         mov cl, 7
   ;         @@x_byte_loop:
   ;             mov al, [byte ptr edi]  ; move value at addr in ebx to eax to perform calculations (check bit at position ecx)
   ;             shr al, cl             ; bitshift MUST be CL or a constant, nothing else!
   ;             and al, 1
   ;             cmp al, 0
   ;             je @@x_byte_continue
   ;             call drawPixel, [@@x_coord], [@@y_coord], 0Fh

   ;         @@x_byte_continue:
   ;             inc [@@x_coord]
   ;             dec cl
   ;             cmp cl, 0
   ;             jge @@x_byte_loop

   ;         @@x_loop_continue:
   ;             pop ecx
   ;             sub ecx, 8
   ;             inc edi
   ;             cmp ecx, 0
   ;             jle @@y_continue
   ;             inc [@@x_coord]
   ;             jmp @@x_loop

   ; @@y_continue:
   ;     inc [@@y_coord]
   ;     mov [@@x_coord], 0
   ;     pop ecx
   ;     inc ecx
   ;     cmp ecx, PIECE_HEIGHT
   ;     je @@return
   ;     jmp @@y_loop

    @@return:
        ret
    
endp drawPiece

;; --------


; draws a single pixel onto the screen 
proc drawPixel
    arg @@x_coordinate:dword, @@y_coordinate:dword, @@color:byte
    uses eax, ebx, edx

    call offsetFromCoordinate, [@@x_coordinate], [@@y_coordinate]
    lea ebx, [framebuffer + eax]
    mov dl, [@@color]

    ; Initially, we made a mistake by moving edx to [ebx], which resulted in horizontally surrounding pixels turning black.
    ; The problem was that we moved the entire DWORD color (edx), overwriting 32 bits instead of only 8 (for a single pixel).
    ; Solution: 
    mov [ebx], dl

    ret
endp drawPixel

proc offsetFromCoordinate
    arg @@x_coordinate:dword, @@y_coordinate:dword
    mov eax, [@@x_coordinate]
    mov eax, [@@y_coordinate]
    mov eax, SCREENWIDTH
    mul [@@y_coordinate]                 ; multiply screenwidth with y-coordinate -> first pixel address of line in eax
    add eax, [@@x_coordinate]            ; add x-coordinate to first pixel address of line to get complete coordinate address in eax
    ret
endp offsetFromCoordinate

; ----------------------------------------------------------------------------
; Mouse function
; AX = condition mask causing call
; CX = horizontal cursor position
; DX = vertical cursor position
; DI = horizontal counts
; SI = vertical counts
; BX = button state:
;      |F-2|1|0|
;        |  | `--- left button (1 = pressed)
;        |  `---- right button (1 = pressed)
;        `------ unused
; DS = DATASEG
; ES = DATASEG
; ----------------------------------------------------------------------------
PROC mouseHandler
    USES eax, ebx, ecx, edx
    ; We update the lastMouseX and lastMouseY variables. When the frame buffer is drawn again, these values will be used.
    ; The x-coordinate is stored in cx, and the y-coordinate is stored in dx.
    ; Since the lastMouseX and lastMouseY store dwords, we make sure the cx and dx registers are zero-extended to 32 bits.
    movzx ecx, cx
    movzx edx, dx
    mov [lastMouseX], ecx
    mov [lastMouseY], edx
    
    ret
ENDP mouseHandler

PROC main
	sti
	cld

	push ds
	pop	es 

	; set video mode, init registers
    call setupVideo
    
    ; check if the mouse is present
    call mouse_present
    cmp eax, 1
    je @@mouse_present
    ; if mouse is not present, print to stdout and finish
    mov ah, 9
    mov edx, offset msgMissingMouse
    int 21h
    jmp @@finish

    ; install mouse if present
    @@mouse_present:
        call mouse_install, offset mouseHandler

    call drawBoard
    call loadPieces
    
    ;mov eax, [dword ptr string1]
    ;call drawString, 50, 50, eax, 3
	
    @@animation_loop:

        ; TODO frame must be cleared if necessary
        ; TODO something with VBlank
        ;call drawBoard
        ;call drawPieces
        
        call transferFrame

        
        ; check for early termination
        xor al, al
        mov	ah, 01h
        int	16h
        cmp	al, 1Bh
        je	@@finish
        loop @@animation_loop
    

    @@finish:
        call mouse_uninstall
        call terminateProcess



ENDP main



; -------------------------------------------------------------------
; DATA
; -------------------------------------------------------------------
DATASEG
    framebuffer db 64000 dup (0)
    selectedcell dd 1
    leftcellvisible dw 0
    rightcellvisible dw 0
    fontfilename db "GUI\FONT.BIN", 0
    fontarray db FONTFILE_SIZE dup (?)
    
    pionFileName db "bitmaps/pawn.bin", 0
    kingFileName db "bitmaps/king.bin", 0
    queenFileName db "bitmaps/queen.bin", 0
    bishopFileName db "bitmaps/bishop.bin", 0
    knightFileName db "bitmaps/knight.bin", 0
    rookFileName db "bitmaps/rook.bin", 0

    pionArray dd PIECE_SIZE dup (?)
    rookArray dd PIECE_SIZE dup (?)
    knightArray dd PIECE_SIZE dup (?)
    bishopArray dd PIECE_SIZE dup (?)
    queenArray dd PIECE_SIZE dup (?)
    kingArray dd PIECE_SIZE dup (?)

    whiteColor db 35h
    blackColor db 37h

    lastMouseX dd 0
    lastMouseY dd 0

    msgMissingMouse db 'Mouse missing! Terminating ...', 13, 10, '$'
    

; -------------------------------------------------------------------
; STACK
; -------------------------------------------------------------------
STACK 100h

END main

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


proc setupVideo
	USES eax
	mov ax,13h
	
	int 10h
	ret
endp setupVideo
;-----------------------------------------------------------------------?
proc unsetupVideo
	USES eax
	mov ax,03h
	
	int 10h
	ret
endp unsetupVideo
;-----------------------------------------------------------------------?


proc displayString
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
endp displayString



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

    call drawPieces
    ret
    
endp drawBoard

proc drawCell
    uses eax, edx, ecx
    arg @@x:dword, @@y:dword

    mov eax, [@@y]
    mov edx, CELLDIMENSION
    mul edx
    mov edx, SCREENWIDTH
    mul edx                 
    mov ebx, eax            ; ebx contains offset of first pixel of the line containing the top-left corner of the cell
    mov eax, [@@x] 
    mov edx, CELLDIMENSION
    mul edx                 ; eax contains the x-coordinate of the top-left corner of the cell
    add ebx, eax            ; (ebx = ebx + eax) containing the offset off the top-left corner pixel of the cell
    
    call determineCellColor, [@@x], [@@y]     ; color in al

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

proc determineCellColor
    arg @@x:dword, @@y:dword
    ; returns eax
    mov eax, [@@x]
    movzx ecx, [selectedCellX]
    cmp eax, ecx
    jne @@getColor
    mov eax, [@@y]
    movzx ecx, [selectedCellY]
    cmp eax, ecx
    jne @@getColor
    xor eax, eax
    mov al, 02h
    jmp @@return

    @@getColor:
        mov eax, [@@x]
        add eax, [@@y]          ; xPos + yPos
        shr eax, 1              ; test whether sum is even: bitshift 1 position to the right
        jc @@unevenColor        ; if carry flag (CF) is 1, then the sum was uneven
    @@evenColor:
        mov al, [whiteColor]
        jmp @@return

    @@unevenColor:
        mov al, [blackColor]

    @@return:
        ret

endp determineCellColor


proc transferFrame
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
endp transferFrame

; Terminate the program.
proc terminateProcess
	USES eax
	call unsetupVideo
	mov	ax,04C00h
	int 21h
	ret
endp terminateProcess



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
    ret
endp loadPieces

proc drawPieces
    uses eax, ebx, ecx, edx, edi

    mov edi, offset pieces
    mov ecx, PIECEAMOUNT
    @@drawLoop:
        push ecx
        movzx eax, [word ptr edi]
        push eax
        call typeFromEncPiece, eax
        call pieceArrayFromType, eax
        mov edx, eax
        pop eax
        push eax
        call playerFromEncPiece, eax
        call colorFromPlayer, eax
        mov ecx, eax
        pop eax
        call coordinatesFromEncPiece, eax
        call drawPiece, edx, eax, ebx, ecx
        add edi, 2
        pop ecx
        loop @@drawLoop

    ; white pieces
    ;call drawPiece, offset pionArray, 0, 1, 0Fh
    ;call drawPiece, offset pionArray, 1, 1, 0Fh
    ;call drawPiece, offset pionArray, 2, 1, 0Fh
    ;call drawPiece, offset pionArray, 3, 1, 0Fh
    ;call drawPiece, offset pionArray, 4, 1, 0Fh
    ;call drawPiece, offset pionArray, 5, 1, 0Fh
    ;call drawPiece, offset pionArray, 6, 1, 0Fh
    ;call drawPiece, offset pionArray, 7, 1, 0Fh
    ;call drawPiece, offset rookArray, 0, 0, 0Fh
    ;call drawPiece, offset rookArray, 7, 0, 0Fh
    ;call drawPiece, offset knightArray, 1, 0, 0Fh
    ;call drawPiece, offset knightArray, 6, 0, 0Fh
    ;call drawPiece, offset bishopArray, 2, 0, 0Fh
    ;call drawPiece, offset bishopArray, 5, 0, 0Fh
    ;call drawPiece, offset queenArray, 3, 0, 0Fh
    ;call drawPiece, offset kingArray, 4, 0, 0Fh

    ; black pieces
    ;call drawPiece, offset pionArray, 0, 6, 00h
    ;call drawPiece, offset pionArray, 1, 6, 00h
    ;call drawPiece, offset pionArray, 2, 6, 00h
    ;call drawPiece, offset pionArray, 3, 6, 00h
    ;call drawPiece, offset pionArray, 4, 6, 00h
    ;call drawPiece, offset pionArray, 5, 6, 00h
    ;call drawPiece, offset pionArray, 6, 6, 00h
    ;call drawPiece, offset pionArray, 7, 6, 00h
    ;call drawPiece, offset rookArray, 0, 7, 00h
    ;call drawPiece, offset rookArray, 7, 7, 00h
    ;call drawPiece, offset knightArray, 1, 7, 00h
    ;call drawPiece, offset knightArray, 6, 7, 00h
    ;call drawPiece, offset bishopArray, 2, 7, 00h
    ;call drawPiece, offset bishopArray, 5, 7, 00h
    ;call drawPiece, offset queenArray, 3, 7, 00h
    ;call drawPiece, offset kingArray, 4, 7, 00h

    ret
endp drawPieces

proc updatePiecePosition
    arg @@pieceAddress:dword, @@x:dword, @@y:dword
    uses eax, ebx, edx, edi
    mov edi, [@@pieceAddress]
    movzx eax, [word ptr edi]
    and eax, 11111000000b
    mov ebx, [@@x]
    mov edx, [@@y]
    and ebx, 111b       ; Just to be sure that the x-coordinate is not larger than 7.
    and edx, 111b       ;
    shl ebx, 3          ; Shift 3 y coordinate bits 3 positions to the left to make room for the 3 x coordinate bits.
    or ebx, edx         ; Combine the x and the y coordinate bits.
    or eax, ebx         ; Combine the x and y coordinate bits with the piece type and color bits.
    mov [word ptr edi], ax
    ret
endp updatePiecePosition

proc coordinatesFromEncPiece
    arg @@encodedPiece:dword
    xor eax, eax
    xor ebx, ebx
    mov eax, [@@encodedPiece]
    and eax, 111000b
    shr eax, 3
    mov ebx, [@@encodedPiece]
    and ebx, 111b
    ret
endp coordinatesFromEncPiece

proc typeFromEncPiece
    arg @@encodedPiece:dword
    xor eax, eax
    mov eax, [@@encodedPiece]
    and eax, 1111000000b
    shr eax, 6
    ret
endp typeFromEncPiece

proc playerFromEncPiece
    arg @@encodedPiece:dword
    xor eax, eax
    mov eax, [@@encodedPiece]
    and eax, 10000000000b
    shr eax, 10
    ret
endp playerFromEncPiece

proc colorFromPlayer
    arg @@player:dword
    xor eax, eax
    mov eax, [@@player]
    cmp eax, 0
    je @@white
    movzx eax, [blackPieceColor]
    jmp @@return
    @@white:
        movzx eax, [whitePieceColor]
    @@return:
        ret
endp colorFromPlayer

proc pieceArrayFromType
    arg @@type:dword
    mov eax, [@@type]
    cmp eax, 7
    jle @@typePawn
    cmp eax, 9
    jle @@typeRook
    cmp eax, 11
    jle @@typeKnight
    cmp eax, 13
    jle @@typeBishop
    cmp eax, 14
    je @@typeQueen
    cmp eax, 15
    je @@typeKing

    @@typePawn:
        mov eax, offset pionArray
        jmp @@return
    @@typeRook:
        mov eax, offset rookArray
        jmp @@return
    @@typeKnight:
        mov eax, offset knightArray
        jmp @@return
    @@typeBishop:
        mov eax, offset bishopArray
        jmp @@return
    @@typeQueen:
        mov eax, offset queenArray
        jmp @@return
    @@typeKing:
        mov eax, offset kingArray

    @@return:
        ret
endp pieceArrayFromType

proc findPieceAddress
    arg @@x:dword, @@y:dword
    uses edi, ecx
    xor eax, eax
    xor ebx, ebx
    lea edi, [word ptr pieces]
    mov ecx, PIECEAMOUNT
    @@search:
        movzx eax, [word ptr edi]
        call coordinatesFromEncPiece, eax
        cmp eax, [@@x]
        jne @@next
        cmp ebx, [@@y]
        je @@found

    @@next:
        add edi, 2
        loop @@search
        jmp @@notFound
    @@found:
        mov eax, edi
        jmp @@return
    @@notFound:
        xor eax, eax
    @@return:
        ret
endp findPieceAddress

proc drawPiece
    arg @@dataBuffer:dword, @@x:dword, @@y:dword, @@color:dword
    uses eax, ebx, ecx, edx, edi

    ; Convert the grid x- and y-coorindates to pixel coordinates.
    mov eax, [@@x]
    mov ebx, CELLDIMENSION
    mul ebx
    mov [@@x], eax

    mov eax, [@@y]
    mov ebx, CELLDIMENSION
    mul ebx
    mov [@@y], eax

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

proc gridCoordinateFromPixelCoordinate
    arg @@xPixel:dword, @@yPixel:dword
    uses edx, ecx
    mov ecx, CELLDIMENSION

    xor ebx, ebx
    xor edx, edx    ; We must clear the edx register before using the div instruction.
    mov eax, [@@yPixel]
    div ecx
    mov ebx, eax
    xor edx, edx
    mov eax, [@@xPixel]
    div ecx
    ret
endp gridCoordinateFromPixelCoordinate

proc selectedPiece
    uses ebx
    movzx eax, [selectedCellX]
    cmp eax, 8
    jge @@notSelected
    movzx ebx, [selectedCellY]
    cmp ebx, 8
    jge @@notSelected
    jmp @@selected

    @@notSelected:
        xor eax, eax
        jmp @@return
    @@selected:
        call findPieceAddress, eax, ebx
    @@return:
        ret
endp selectedPiece

proc selectCell
    arg @@xPixel:dword , @@yPixel:dword
    uses eax, ebx, edx
    call gridCoordinateFromPixelCoordinate, [@@xPixel], [@@yPixel]      ; returns the grid x-coordinate in eax and the grid y-coordinate in ebx
    push eax
    push ebx
    call findPieceAddress, eax, ebx         ; Returns the address of the piece in eax. If no piece is found, eax is set to 0.
    cmp eax, 0
    je @@destinationSelection
    mov eax, [eax]
    call playerFromEncPiece, eax             ; Returns the player (0 or 1) in al
    movzx ebx, [currentTurn]
    cmp eax, ebx
    jne @@unselect
    pop ebx
    pop eax
    mov [selectedCellX], al
    mov [selectedCellY], bl
    jmp @@return

    @@unselect:
        pop ebx
        pop eax
        mov [selectedCellX], 8
        mov [selectedCellY], 8

    @@destinationSelection:
        call selectedPiece      ; Returns the address of the selected piece in eax. If no piece is selected, eax is set to 0.
        cmp eax, 0              ; If no piece is selected, we do nothing.
        je @@return
        mov edx, eax            ; If a piece is selected, it will be moved to the destination cell.
        pop ebx
        pop eax
        call updatePiecePosition, edx, eax, ebx

    @@return:
        call drawBoard
        ret
endp selectCell

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
    
    ; We check if the left mouse button is pressed. If this is the case, we update the selected cell.
    and bl, 3
    jz @@return
    call selectCell, ecx, edx

    @@return:
        call transferFrame
        ret
ENDP mouseHandler

PROC main
	sti
	cld

	push ds
	pop	es 

	; set video mode, init registers
    call setupVideo
    mov eax, 78
    mov ebx, 25
    call selectCell, eax, ebx
    
    ; We check if the mouse is present. If this is not the case, we print a message to the screen and terminate the program.
    ; If the mouse is present, we install the mouse handler.
    call mouse_present
    cmp eax, 1
    je @@mouse_present
    mov ah, 9
    mov edx, offset msgMissingMouse
    int 21h
    jmp @@finish
    @@mouse_present:
        call mouse_install, offset mouseHandler

    ; Load the pieces from the bitmap files and draw the board with pieces.
    call loadPieces
    call drawBoard
    call transferFrame

    ; TEST CASE
    mov eax, 5
    mov ebx, 12
    call selectCell, eax, ebx
    mov eax, 50
    mov ebx, 56
    call selectCell, eax, ebx
    
    @@animation_loop:

        ; TODO frame must be cleared if necessary
        ; TODO something with VBlank
        ;call drawBoard
        ;call drawPieces
        
        ;call transferFrame

        
        ; check for termination by ESC key
        xor al, al
        mov	ah, 01h
        int	16h
        cmp	al, 1Bh
        je	@@finish
        jmp @@animation_loop
    

    @@finish:
        call mouse_uninstall
        call terminateProcess



ENDP main



; -------------------------------------------------------------------
; DATA
; -------------------------------------------------------------------
DATASEG
    
    ; Each chess piece is encoded in a word. The format is as follows (where B represents a bit):
    ;       B   BBBB   BBB   BBB
    ;       |   |      |     |
    ;      (1) (2)    (3)   (4)
    ;
    ; (1):  PLAYER
    ;       0 = white
    ;       1 = black
    ; (2):  PIECE TYPE
    ;       0000 until 0111     = pawns
    ;       1000 and 1001       = rooks
    ;       1010 and 1011       = knights
    ;       1100 and 1101       = bishops
    ;       1110                = queen
    ;       1111                = king
    ; (3):  X-COORDINATE
    ; (4):  Y-COORDINATE
    
    pieces  dw 01000000000b, 01010001000b, 01100010000b, 01110011000b, 01111100000b, 01101101000b, 01011110000b, 01001111000b
            dw 00000000001b, 00001001001b, 00010010001b, 00011011001b, 00100100001b, 00101101001b, 00110110001b, 00111111001b
            dw 11000000110b, 11010001110b, 11100010110b, 11110011110b, 11111100110b, 11101101110b, 11011110110b, 11001111110b
            dw 10000000111b, 10001001111b, 10010010111b, 10011011111b, 10100100111b, 10101101111b, 10110110111b, 10111111111b

    framebuffer db 64000 dup (0)
    selectedcell dd 1
    leftcellvisible dw 0
    rightcellvisible dw 0
    fontfilename db "GUI\FONT.BIN", 0
    ;fontarray db FONTFILE_SIZE dup (?)
    
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

    whitePieceColor db 0Fh
    blackPieceColor db 00h

    lastMouseX dd 0
    lastMouseY dd 0

    msgMissingMouse db 'Mouse missing! Terminating ...', 13, 10, '$'

    selectedCellX db 8
    selectedCellY db 8

    currentTurn db 0
    

; -------------------------------------------------------------------
; STACK
; -------------------------------------------------------------------
STACK 100h

END main

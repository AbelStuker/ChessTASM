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
	uses eax
	mov ax,13h
	
	int 10h
	ret
endp setupVideo
;-----------------------------------------------------------------------?
proc unsetupVideo
	uses eax
	mov ax,03h
	
	int 10h
	ret
endp unsetupVideo
;-----------------------------------------------------------------------?

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

;proc drawCell
;    uses eax, edx, ecx
;    arg @@x:dword, @@y:dword

    ; Calculate the offset of the top-left corner pixel of the cell.
    ; The offset is calculated by multiplying the y-coordinate with the celldimension to obtain the pixel y-coordinate.
    ; Then, the pixel y-coordinate is multiplied with the screenwidth to obtain the offset of the first pixel of the line containing the top-left corner of the cell.
    ; After that, the x-coordinate is multiplied with the celldimension to obtain the pixel x-coordinate.
    ; Lastly, the pixel x-corodinate is added to the offset of the first pixel of the line.
    ; We now have the offset of the top-left corner pixel of the cell.
;    mov eax, [@@y]
;    mov edx, CELLDIMENSION
;    mul edx 
;    mov edx, SCREENWIDTH
;    mul edx                 
;    mov ebx, eax            ; ebx contains offset of first pixel of the line containing the top-left corner of the cell
;    mov eax, [@@x] 
;    mov edx, CELLDIMENSION
;    mul edx                 ; eax contains the x-coordinate of the top-left corner of the cell
;    add ebx, eax            ; (ebx = ebx + eax) containing the offset off the top-left corner pixel of the cell
    
;    call determineCellColor, [@@x], [@@y]     ; The color of the cell is obtained in eax.

;    xor edx, edx    
;    @@verticalLoop:
;        mov ecx, CELLDIMENSION;

;        @@horizontalLoop:
;            mov [framebuffer + ebx + ecx - 1], al
;            loop @@horizontalLoop

;        inc edx
;        add ebx, SCREENWIDTH        ; add screenwidth to ebx (offset) to jump to the leftmost pixel at the next line
;        cmp edx, CELLDIMENSION
;        jl @@verticalLoop

;    ret

;endp drawCell


proc drawCell
    uses eax, edx, ecx
    arg @@x:dword, @@y:dword
    local @@pixelX:dword, @@pixelY:dword

    ; Converting the grid-coordinates into pixel-coordinates.
    ;   Calculate the offset of the top-left corner pixel of the cell.
    ;   The offset is calculated by multiplying the y-coordinate with the celldimension to obtain the pixel y-coordinate.
    ;   After that, the x-coordinate is multiplied with the celldimension to obtain the pixel x-coordinate.
    mov eax, [@@y]
    mov ebx, CELLDIMENSION
    xor edx, edx
    mul ebx         
    mov [@@pixelY], eax
    
    mov eax, [@@x] 
    mov ebx, CELLDIMENSION
    xor edx, edx
    mul ebx
    mov [@@pixelX], eax

    ; Determine the color based on the grid coordinates of the cell.
    call determineCellColor, [@@x], [@@y]     ; The color of the cell is obtained in eax.

    call drawRectangle, [@@pixelX], [@@pixelY], CELLDIMENSION, CELLDIMENSION, eax
    ret

endp drawCell

proc drawRectangle
    arg @@x:dword, @@y:dword, @@width:dword, @@height:dword, @@color:dword
    uses eax, edx, ecx, ebx

    ; The pixel y-coordinate is multiplied with the screenwidth to obtain the offset of the first pixel of the line containing the top-left corner of the cell.
    ; Then, the pixel x-corodinate is added to the offset of the first pixel of the line.
    ; We now have the offset of the top-left corner pixel of the cell.

    mov eax, [@@y]
    mov ebx, SCREENWIDTH
    xor edx, edx
    mul ebx
    mov ebx, eax            ; ebx contains offset of first pixel of the line containing the top-left corner of the cell
    mov eax, [@@x]          ; eax contains the x-coordinate of the top-left corner of the cell
    add ebx, eax            ; (ebx = ebx + eax) containing the offset off the top-left corner pixel of the cell

    mov eax, [@@color]
    xor edx, edx    
    @@verticalLoop:
        mov ecx, [@@width]

        @@horizontalLoop:
            mov [framebuffer + ebx + ecx - 1], al
            loop @@horizontalLoop

        inc edx
        add ebx, SCREENWIDTH        ; add screenwidth to ebx (offset) to jump to the leftmost pixel at the next line
        cmp edx, [@@height]
        jl @@verticalLoop

    ret
endp drawRectangle


proc determineCellColor
    arg @@x:dword, @@y:dword
    uses edx, ecx, ebx

    ; When the current cell is a selected cell, the cell must be coloured green.
    mov eax, [@@x]
    movzx ecx, [selectedCellX]
    cmp eax, ecx
    jne @@checkprevSelectedCell
    mov eax, [@@y]
    movzx ecx, [selectedCellY]
    cmp eax, ecx
    jne @@checkprevSelectedCell
    xor eax, eax
    mov al, 78h
    jmp SHORT @@return

    @@checkprevSelectedCell:
        ; When the current cell is a previously selected cell (source of a piece move).
        mov eax, [@@x]
        movzx ecx, [prevSelectedCellX]
        cmp eax, ecx
        jne @@checkMouseHover
        mov eax, [@@y]
        movzx ecx, [prevSelectedCellY]
        cmp eax, ecx
        jne @@checkMouseHover
        xor eax, eax
        mov al, 75h
        jmp @@return

    @@checkMouseHover:
        ; When the mouse is present in the current cell, the cell must be coloured blue.
        call gridCoordinateFromPixelCoordinate, [lastMouseX], [lastMouseY]  ; Returns the x- and y-coordinate of the cell in which the mouse is in eax and ebx respectively.
        mov edx, [@@x]
        cmp edx, eax
        jne @@getColor
        mov edx, [@@y]
        cmp edx, ebx
        jne @@getColor
        xor eax, eax
        mov al, [turnColor]
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
	uses eax, ecx, edi, esi

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
	uses eax
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
    jnc @@return
    call terminateProcess
    @@return:
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
                                ; amount of bytes read in ax (or error code)
    jnc @@return

    call terminateProcess       

    @@return:
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

proc loadBitmap
    arg @@fileName:dword, @@dataBuffer:dword, @@size:dword
    uses eax, ebx
    
    call getFileHandle, [@@fileName], 0
    mov ebx, eax
    call readFile, ebx, [@@dataBuffer], [@@size]
    call closeFile, ebx

    ret

endp loadBitmap

proc loadFont
    call loadBitmap, offset asciiFileName, offset asciiArray, ASCII_FONT_BYTES
    ret
endp loadFont

proc loadPieces
    call loadBitmap, offset pionFileName, offset pionArray, BYTES_PER_PIECE
    call loadBitmap, offset rookFileName, offset rookArray, BYTES_PER_PIECE
    call loadBitmap, offset knightFileName, offset knightArray, BYTES_PER_PIECE
    call loadBitmap, offset bishopFileName, offset bishopArray, BYTES_PER_PIECE
    call loadBitmap, offset queenFileName, offset queenArray, BYTES_PER_PIECE
    call loadBitmap, offset kingFileName, offset kingArray, BYTES_PER_PIECE
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
        call aliveFromEncPiece, eax
        cmp eax, 0
        pop eax
        je @@continue
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

        @@continue:
            add edi, 2
            pop ecx
            loop @@drawLoop
    ret
endp drawPieces

proc getAbsoluteDifference
    arg @@a:dword, @@b:dword
    uses ebx
    mov eax, [@@a]
    mov ebx, [@@b]
    cmp eax, ebx
    jl @@switch
    sub eax, ebx
    jmp @@return
    @@switch:
        sub ebx, eax
        mov eax, ebx
    @@return:
        ret
endp getAbsoluteDifference

proc getSmallestValue
    arg @@a:dword, @@b:dword
    mov eax, [@@a]
    cmp eax, [@@b]
    jle @@return
    mov eax, [@@b]
    @@return:
        ret
endp getSmallestValue

proc isPathEmpty
    arg @@startX:dword, @@endX:dword, @@startY:dword, @@endY:dword
    local @@pathType:dword
    uses ecx, edx, ebx

    mov edx, [@@startY]
    cmp edx, [@@endY]
    je @@prepareHorizontal
    mov edx, [@@startX]
    cmp edx, [@@endX]
    je @@prepareVertical
    call getAbsoluteDifference, [@@startY], [@@endY]
    mov ebx, eax
    call getAbsoluteDifference, [@@startX], [@@endX]
    cmp eax, ebx
    je @@prepareDiagonal
    jmp @@notEmpty          ; In case the path between the start and end coordinates is neither horizontal nor vertical, we say the path is not empty.


    @@prepareHorizontal:
        mov [@@pathType], 0
        call getAbsoluteDifference, [@@startX], [@@endX]
        mov ecx, eax
        call getSmallestValue, [@@startY], [@@endY]
        mov ebx, eax
        call getSmallestValue, [@@startX], [@@endX]
        inc eax             ; Since the first cell contains the piece we are trying to move, we must exclude this cell from the check because it will never be empty.
        jmp SHORT @@check
    @@prepareVertical:
        mov [@@pathType], 1
        call getAbsoluteDifference, [@@startY], [@@endY]
        mov ecx, eax
        call getSmallestValue, [@@startY], [@@endY]
        mov ebx, eax
        call getSmallestValue, [@@startX], [@@endX]
        inc ebx
        jmp @@check
    @@prepareDiagonal:
        call getAbsoluteDifference, [@@startX], [@@endX]
        mov ecx, eax
        mov eax, [@@startX]
        cmp eax, [@@endX]
        jl @@diagonalFromLeft
        jmp @@diagonalFromRight
        @@diagonalFromLeft:
            mov [@@pathType], 2
            inc eax
            jmp @@checkDiagonalVBegin
        @@diagonalFromRight:
            dec eax
            mov [@@pathType], 4
        @@checkDiagonalVBegin:
            mov ebx, [@@startY]
            cmp ebx, [@@endY]
            jge @@diagonalFromBottom
        @@diagonalFromTop:
            inc ebx
            jmp @@check
        @@diagonalFromBottom:
            dec ebx
            add [@@pathType], 1
            jmp @@check

    @@check:
        
        dec ecx     ; Since we don't want to check the end coordinate, we substract 1 from ecx (ecx contains the amount of cells between the start and end coordinate).
                    ;       The destination cell can not contain an own piece, since it would be selected instead of the cell as destination.
                    ;       The destination cell can be a piece of the other player, in which case the move is possible and that piece will die.

       
        jcxz @@entirePathEmpty      ; If the destination cell is next to the piece we are trying to move, the path in between is non-existing and therefore always empty.

        ; Looping over the path.
        ; When a piece is found, the path is not empty.
        @@testEmpty:
            push eax
            call findPieceAddress, eax, ebx
            cmp eax, 0      ; If the cell is empty, eax is set to 0.
            pop eax
            je @@empty
            jmp @@notEmpty

            @@empty:
                mov edx, [@@pathType]
                cmp edx, 0      ; If the path is horizontal
                je @@incX       ;   we increment the x-coordinate.
                cmp edx, 1      ; If the path is vertical
                je @@incY       ;   we increment the y-coordinate.
                cmp edx, 2      ; If the path is diagonal from top left to bottom right
                je @@incXY      ;   we increment both the x- and y-coordinate.
                cmp edx, 3      ; If the path is diagonal from bottom left to top right
                je @@incXdecY   ;   we increment the x-coordinate and decrement the y-coordinate.
                cmp edx, 4      ; If the path is diagonal from top right to bottom left
                je @@decXincY   ;   we decrement the x-coordinate and increment the y-coordinate.
                cmp edx, 5      ; If the path is diagonal from bottom right to top left
                je @@decXY      ;   we decrement both the x- and y-coordinate.
            
            @@incX:
                inc eax
                jmp @@continue
            @@incY:
                inc ebx
                jmp @@continue
            @@incXY:
                inc eax
                inc ebx
                jmp @@continue
            @@incXdecY:
                inc eax
                dec ebx
                jmp @@continue
            @@decXincY:
                dec eax
                inc ebx
                jmp @@continue
            @@decXY:
                dec eax
                dec ebx
            @@continue:
                loop @@testEmpty
                jmp @@entirePathEmpty
    

    @@notEmpty:
        xor eax, eax
        jmp @@return
    @@entirePathEmpty:
        mov eax, 1
    @@return:
        ret
endp isPathEmpty

proc setEnPassantCell
    arg @@destinationX:dword, @@destinationY:dword, @@direction:dword
    uses eax, ebx

    cmp [@@direction], 0
    mov eax, [@@destinationY]
    je @@above
    dec eax
    jmp @@encode
    @@above:
    inc eax

    @@encode:
    mov [@@destinationY], eax
    mov eax, [@@destinationX]
    shl eax, 5
    mov ebx, [@@destinationY]
    shl ebx, 2
    or eax, ebx
    mov ebx, [@@direction]
    shl ebx, 1
    or eax, ebx
    or eax, 1
    mov [enPassantState], eax
    ret

endp setEnPassantCell

proc isEnPassantCell
    arg @@destinationX:dword, @@destinationY:dword

    mov ebx, [enPassantState]
    mov eax, ebx
    and eax, 1
    cmp eax, 0                      ; If the en passant state is not active, the cell can never be the en passant cell.
    je @@notPossible
    mov eax, ebx
    shr eax, 2
    and eax, 111b                   ; We extract the y-coordinate of the en passant cell
    cmp eax, [@@destinationY]       ;   and compare it with the y-coordinate of the provided cell.
    jne @@notPossible
    mov eax, ebx
    shr eax, 5
    and eax, 111b                   ; We extract the x-coordinate of the en passant cell
    cmp eax, [@@destinationX]       ;   and compare it with the x-coordinate of the provided cell.
    jne @@notPossible
    mov eax, ebx                    ; When all checks are passed, the provided cell is the enPassantCell.
    shr eax, 1
    and eax, 1                      ; We extract the direction of the cell where the piece needs to be killed (0 = above, 1 = below).
    mov ebx, [@@destinationY]
    cmp eax, 0
    je @@aboveKilled
    inc ebx                         ; If the direction bit is 1, the piece below must be killed so return register ebx must contain the destinationY + 1.
    jmp @@possible
    @@aboveKilled:
        dec ebx                     ; If the direction bit is 0, the piece above must be killed so return register eax must contain the destinationY - 1.

    @@possible:
        mov eax, 1
        jmp @@return

    @@notPossible:
        mov eax, 0
    
    @@return:
        ret

endp isEnPassantCell

;; Procedures to check moves of individual piece types.
proc checkPawnMove
    arg @@pieceX:dword, @@pieceY:dword, @@destinationX:dword, @@destinationY:dword, @@destinationOccupation:dword, @@player:byte
    uses ebx
    cmp [@@player], 1
    je @@blackPawn
    jmp @@whitePawn

    @@blackPawn:
        mov ebx, [@@pieceY]
        sub ebx, [@@destinationY]
        jmp @@pawnTestY
    @@whitePawn:
        mov ebx, [@@destinationY]
        sub ebx, [@@pieceY]
    @@pawnTestY:
        cmp ebx, 1
        je @@pawnTestX
        cmp ebx, 2
        je @@pawnTestFirstMove
        jmp @@notPossible
    @@pawnTestFirstMove:
        call getAbsoluteDifference, [@@pieceX], [@@destinationX]
        cmp eax, 0
        jne @@notPossible

        cmp [@@player], 1
        je @@pawnTestFirstMoveBlack
        jmp @@pawnTestFirstMoveWhite
        @@pawnTestFirstMoveBlack:
            cmp [@@pieceY], 6
            jne @@notPossible
            call setEnPassantCell, [@@destinationX], [@@destinationY], 0
            jmp @@possible
        @@pawnTestFirstMoveWhite:
            cmp [@@pieceY], 1
            jne @@notPossible
            call setEnPassantCell, [@@destinationX], [@@destinationY], 1
            jmp @@possible
    @@pawnTestX:
        call getAbsoluteDifference, [@@pieceX], [@@destinationX]
        cmp eax, 0
        je @@testPawnVertical
        cmp eax, 1
        je @@testPawnDiagonal
        jmp @@notPossible
    @@testPawnDiagonal:
        cmp [@@destinationOccupation], 0        ; If the diagonal cell is not occupied, the move is not possible.
        je @@testEnPassant
        jmp @@possible                          ; If the diagonal cell is occupied, it must be occupied by the other player (because we already checked if it was occupied by the same player).
    @@testPawnVertical:
        cmp [@@destinationOccupation], 0        ; If the vertical cell is occupied, the move is not possible.
        je @@possible
        jmp @@testEnPassant
    @@testEnPassant:
        call isEnPassantCell, [@@destinationX], [@@destinationY]
        cmp eax, 0
        je @@notPossible
        jmp @@possible

    @@possible:
        mov eax, 1
        jmp @@return
    @@notPossible:
        xor eax, eax
    @@return:
        ret

endp checkPawnMove

proc checkRookMove
    arg @@pieceX:dword, @@pieceY:dword, @@destinationX:dword, @@destinationY:dword
    
    call getAbsoluteDifference, [@@pieceX], [@@destinationX]
    cmp eax, 0
    jne @@testRookYsteady
    call getAbsoluteDifference, [@@pieceY], [@@destinationY]
    cmp eax, 0
    jne @@testRookXsteady
    jmp @@notPossible
    @@testRookYsteady:
        mov eax, [@@pieceY]
        cmp eax, [@@destinationY]
        je @@testPathEmpty
        jmp @@notPossible
    @@testRookXsteady:
        mov eax, [@@pieceX]
        cmp eax, [@@destinationX]
        je @@testPathEmpty
        jmp @@notPossible

    @@testPathEmpty:
            call isPathEmpty, [@@pieceX], [@@destinationX], [@@pieceY], [@@destinationY]
            cmp eax, 0
            je @@notPossible
            jmp @@possible
    @@possible:
        mov eax, 1
        jmp @@return
    @@notPossible:
        xor eax, eax
    @@return:
        ret
endp checkRookMove

proc checkKnightMove
    arg @@pieceX:dword, @@pieceY:dword, @@destinationX:dword, @@destinationY:dword
    uses ebx

    call getAbsoluteDifference, [@@pieceY], [@@destinationY]
    mov ebx, eax
    call getAbsoluteDifference, [@@pieceX], [@@destinationX]
    cmp eax, 1
    je @@checkYDifference2
    cmp eax, 2
    je @@checkYDifference1
    jmp @@notPossible
    @@checkYDifference2:
        cmp ebx, 2
        je @@possible
        jmp @@notPossible
    @@checkYDifference1:
        cmp ebx, 1
        je @@possible
        jmp @@notPossible
    @@possible:
        mov eax, 1
        jmp @@return
    @@notPossible:
        xor eax, eax
    @@return:
        ret
endp checkKnightMove

proc checkBishopMove
    arg @@pieceX:dword, @@pieceY:dword, @@destinationX:dword, @@destinationY:dword
    uses ebx

    call getAbsoluteDifference, [@@pieceY], [@@destinationY]
    mov ebx, eax
    call getAbsoluteDifference, [@@pieceX], [@@destinationX]
    cmp eax, ebx
    jne @@notPossible
    call isPathEmpty, [@@pieceX], [@@destinationX], [@@pieceY], [@@destinationY]
    cmp eax, 0
    je @@notPossible
    @@possible:
        mov eax, 1
        jmp @@return
    @@notPossible:
        xor eax, eax
    @@return:
        ret
endp checkBishopMove

proc checkQueenMove
    arg @@pieceX:dword, @@pieceY:dword, @@destinationX:dword, @@destinationY:dword
    call isPathEmpty, [@@pieceX], [@@destinationX], [@@pieceY], [@@destinationY]
    cmp eax, 0
    je @@notPossible
    @@possible:
        mov eax, 1
        jmp @@return
    @@notPossible:
        xor eax, eax
    @@return:
        ret
endp checkQueenMove

proc checkKingMove
    arg @@pieceX:dword, @@pieceY:dword, @@destinationX:dword, @@destinationY:dword

    call getAbsoluteDifference, [@@pieceY], [@@destinationY]
    cmp eax, 1
    je @@possible
    cmp eax, 0
    jne @@notPossible
    call getAbsoluteDifference, [@@pieceX], [@@destinationX]
    cmp eax, 1
    je @@possible
    jmp @@notPossible
    @@possible:
        mov eax, 1
        jmp @@return
    @@notPossible:
        xor eax, eax
    @@return:
        ret
endp checkKingMove

proc calculatePossibleMove
    arg @@encodedPiece:dword, @@destinationX:dword, @@destinationY:dword
    local @@player:dword, @@type:byte, @@pieceX:dword, @@pieceY:dword, @@destinationOccupation:dword
    uses ebx

    call coordinatesFromEncPiece, [@@encodedPiece]
    mov [@@pieceX], eax
    mov [@@pieceY], ebx
    call typeFromEncPiece, [@@encodedPiece]
    mov [@@type], al
    call playerFromEncPiece, [@@encodedPiece]
    mov [@@player], eax

    ; Check if the destination cell is occupied by another piece. If this piece is from the same player, the move is not possible.
    ; If the piece is from the other player, it must be checked wheter killing the piece is possible.
    call findPieceAddress, [@@destinationX], [@@destinationY]
    mov [@@destinationOccupation], eax
    cmp eax, 0
    je @@checkMove
    call playerFromEncPiece, [dword ptr eax]
    cmp al, [currentTurn]   ; TODO remove this check because that other piece would have been selected as piece and not the cell as destination
    je @@notPossible

    @@checkMove:
        mov al, [@@type]
        cmp al, 7
        jle @@typePawn
        cmp al, 9
        jle @@typeRook
        cmp al, 11
        jle @@typeKnight
        cmp al, 13
        jle @@typeBishop
        cmp al, 14
        je @@typeQueen
        cmp al, 15
        je @@typeKing
        jmp @@notPossible

        @@typePawn:
            call checkPawnMove, [@@pieceX], [@@pieceY], [@@destinationX], [@@destinationY], [@@destinationOccupation], [@@player]
            cmp eax, 0
            je @@notPossible
            jmp @@possible

        @@typeRook:
            call checkRookMove, [@@pieceX], [@@pieceY], [@@destinationX], [@@destinationY]
            cmp eax, 0
            je SHORT @@notPossible
            jmp SHORT @@possible

        @@typeKnight:
            call checkKnightMove, [@@pieceX], [@@pieceY], [@@destinationX], [@@destinationY]
            cmp eax, 0
            je @@notPossible
            jmp @@possible

        @@typeBishop:
            call checkBishopMove, [@@pieceX], [@@pieceY], [@@destinationX], [@@destinationY]
            cmp eax, 0
            je @@notPossible
            jmp @@possible
            
        @@typeQueen:
            call checkQueenMove, [@@pieceX], [@@pieceY], [@@destinationX], [@@destinationY]
            cmp eax, 0
            je @@notPossible
            jmp @@possible

        @@typeKing:
            call checkKingMove, [@@pieceX], [@@pieceY], [@@destinationX], [@@destinationY]
            cmp eax, 0
            je @@notPossible
            jmp @@possible

    @@possible:
        mov eax, [@@encodedPiece]
        jmp @@return
    @@notPossible:
        xor eax, eax
    @@return:
        ret
endp calculatePossibleMove

proc killPiece
    arg @@pieceAddress:dword
    uses eax, edi
    mov edi, [@@pieceAddress]
    movzx eax, [word ptr edi]
    and eax, 011111111111b
    mov [word ptr edi], ax
    ret
endp killPiece

proc movePiece
    arg @@pieceAddress:dword, @@x:dword, @@y:dword, @@destPieceAddress:dword
    uses eax, ebx, edx, edi
    mov edi, [@@pieceAddress]
    movzx eax, [word ptr edi]
    call calculatePossibleMove, eax, [@@x], [@@y]
    cmp eax, 0
    je @@return

    ; If the destination contains a piece, we must remove it (since it is killed).
    cmp [@@destPieceAddress], 0
    je @@move
    call killPiece, [@@destPieceAddress]

    @@move:
        ; Updating the previously selected cell
        push eax
        mov al, [selectedCellX]
        mov [prevSelectedCellX], al
        mov al, [selectedCellY]
        mov [prevSelectedCellY], al

        ; Updating the selected cell to the destination cell.
        mov eax, [@@x]
        mov [selectedCellX], al 
        mov eax, [@@y]
        mov [selectedCellY], bl
        pop eax

        ; Updating the position of the piece.
        and eax, 111111000000b
        mov ebx, [@@x]
        mov edx, [@@y]
        and ebx, 111b       ; Just to be sure that the x-coordinate is not larger than 7.
        and edx, 111b       ;
        shl ebx, 3          ; Shift 3 y coordinate bits 3 positions to the left to make room for the 3 x coordinate bits.
        or ebx, edx         ; Combine the x and the y coordinate bits.
        or eax, ebx         ; Combine the x and y coordinate bits with the piece type and color bits.
        mov [word ptr edi], ax

        ; Changing the turn of the player.
        call changeCurrentTurn
    @@return:
        ret
endp movePiece

;;
proc changeCurrentTurn
    uses eax

    mov al, [currentTurn]
    push eax

    ; Update the timer on which the player ended to the time he currently has left.
    cmp al, 0
    je @@white
    mov ebx, [blackTimer]
    mov [blackLastTime], ebx
    jmp @@updateStartTime
    @@white:
        mov ebx, [whiteTimer]
        mov [whiteLastTime], ebx

    ; Updating the starting time of the current turn.
    @@updateStartTime:
        call getTime
        mov [startTime], eax

    ; Changing the current turn indicator.
    pop eax
    xor al, 00000001b
    mov [currentTurn], al
    ret
endp changeCurrentTurn

;; Procedures to obtain properties based on the encoded piece.
proc aliveFromEncPiece
    arg @@encodedPiece:dword
    xor eax, eax
    mov eax, [@@encodedPiece]
    ;and eax, 10000000000b
    shr eax, 11
    ret
endp aliveFromEncPiece

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
    uses edi, ecx, ebx
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
    uses eax, ebx, edx

    ; Convert the grid x- and y-coorindates to pixel coordinates.
    mov eax, [@@x]
    mov ebx, CELLDIMENSION
    mul ebx
    mov [@@x], eax

    mov eax, [@@y]
    mov ebx, CELLDIMENSION
    mul ebx
    mov [@@y], eax

    call drawBitmap, [@@dataBuffer], [@@x], [@@y], PIECE_WIDTH, PIECE_SIZE, [@@color]
    ret
endp drawPiece

proc drawBitmap
    arg @@dataBuffer:dword, @@xPixel:dword, @@yPixel:dword, @@width:dword, @@size:dword, @@color:dword
    ;local @@size:dword
    uses eax, ebx, ecx, edx, edi

    ; Calculate the size of the bitmap
    ;mov eax, [@@width]
    ;mov ebx, [@@height]
    ;mul ebx
    ;mov [@@size], eax

    mov edi, [@@dataBuffer]     ; edi contains address where bitmap starts
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
            div ebx             ; divide index by 8 to get the current byte offset (starting from right in the dword) in eax, current bit offset in byte (starting from right in the byte) in edx
            mov ebx, 7
            sub ebx, edx        ; (7 - bit offset from right) to get current bit starting from left instead of right of byte 
            push ebx
            mov ebx, 8
            mul ebx             ; multiply byte offset with 8 to get bit offset
            pop ebx
            add eax, ebx        ; total offset in eax = byte offset + bit offset (in byte)
            pop edx             ; restore edx (bits counted in buffer)
                                ; This does not correspond to the actual bit index, since we read each dword backwards due to little endian memory organisation.
            add eax, edx        ; In order to calculate the total offset, we add the current bit offset in the current dword (eax) to the offset where the current
            sub eax, ecx        ;   dword begins (i.e. the total amount of bits counted minus the amount of bits counted in the current dword: eax - ecx).
            mov ebx, [@@width]
            push edx            ; store edx (byte in buffer index) because edx is used to store remainder after division
            xor edx, edx
            div ebx             ; y-index in eax, x-index in edx
            add edx, [@@xPixel]
            add eax, [@@yPixel]
            call drawPixel, edx, eax, [@@color]
            pop edx             ; restore edx
        @@continue:
            pop eax
            inc ecx
            inc edx
            cmp edx, [@@size]
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
    
endp drawBitmap

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
    uses eax, ebx, edx, ecx
    call gridCoordinateFromPixelCoordinate, [@@xPixel], [@@yPixel]      ; Returns the grid x-coordinate in eax and the grid y-coordinate in ebx
    push ebx
    push eax
    ; If the destination cell does not contain a piece of the same player, we may want the currently selected piece (if any) to move to this cell.
    call findPieceAddress, eax, ebx     ; Returns the address of the piece at the destination cell in eax. If no piece is found, eax is set to 0.
    push eax                            ; We push this onto the stack since we may need it later in movePiece to remove the piece.
    cmp eax, 0
    je @@destinationSelection
    ; If the destination cell contains a piece, we may want to select this piece if it belongs to the current player.
    ; If it belongs to the other player, we try to move the currently selected piece (if any) to this cell.
    mov eax, [eax]
    call playerFromEncPiece, eax        ; Returns the player (0 or 1) in al
    cmp al, [currentTurn]               ; If the piece in the destination cell ...
    jne @@destinationSelection          ;   ... belongs to the other player, we try to move the currently selected piece (if any) to this cell.
    pop ebx ; thrown away 
    pop eax
    pop ebx
    mov [selectedCellX], al             ;   ... belongs to the current player, we select this piece.
    mov [selectedCellY], bl
    mov [prevSelectedCellX], 8          ; The source of the previous piece movement is no longer relevant.
    mov [prevSelectedCellY], 8          ;
    jmp @@return

    ; ----- currently not used -----
    @@unselect:
        pop eax ; thrown away
        pop eax
        pop eax
        mov [selectedCellX], 8
        mov [selectedCellY], 8
        jmp @@return
    ; ------------------------------

    @@destinationSelection:
        call selectedPiece          ; Returns the address of the selected piece in eax. If no piece is selected, eax is set to 0.
        cmp eax, 0                  ; If no piece is selected, we do nothing.
        je @@return
        mov edx, eax                ; If a piece is selected, it will be moved to the destination cell when possible.
        pop ecx                     ; Popping from stack:   ecx = address of destination piece (can be 0 if no piece is present)
        cmp ecx, 0
        jne @@continue              ; If the destination cell is occupied, we must not check for en passant.
        call typeFromEncPiece, edx  ; Type of the piece in al
        cmp al, 7
        jge @@continue              ; When the currently selected piece is not a rook, we can not have en passant.
        pop eax                     ; Popping from stack:   ebx = y-coordinate of the source piece
        pop ebx                     ;                       eax = x-coorindate of the source piece
        push ebx                    ; Push them again to the stack because the isEnPassantCell procedure will return values in these registers.
        push eax                    ;
        call isEnPassantCell, eax, ebx  ; ebx = y-coordinate of the en passant piece cell
        cmp eax, 0                  ; eax = en passant possible (0 = no, 1 = yes)
        je @@continue
        pop eax
        push eax                    ; Push again on the stack because the findPieceAddress procedure will a value in eax and we need 
        call findPieceAddress, eax, ebx ; Using the y-coordinate returned by the isEnPassantCell procedure (to find the piece to kill).
        cmp eax, 0                  ; Is not supposed to happen.
        je @@continue
        mov ecx, eax                ; edx = address of the piece to kill
     
        @@continue:
        pop eax
        pop ebx
        call movePiece, edx, eax, ebx, ecx

    @@return:
        call drawBoard
        ret
endp selectCell

proc drawString
    arg @@string:dword, @@xPixel:dword, @@yPixel:dword, @@color:dword, @@backgroundColor:dword

    ; To fill the padding of the top and bottom at the end, we need to know the initial x- and y-coordinates.
    push [@@yPixel]
    push [@@xPixel]

    ; Add padding
    add [@@yPixel], CHAR_PADDING
    call drawRectangle, [@@xPixel], [@@yPixel], CHAR_PADDING, CHAR_HEIGHT, [@@backgroundColor]      ; Fill left padding with backgroundcolor.
    add [@@xPixel], CHAR_PADDING

    mov eax, [@@string]
    @@loopString:
        movzx ebx, [byte ptr eax]
        cmp ebx, 0
        je @@return
        call drawCharacter, ebx, [@@xPixel], [@@yPixel], [@@color], [@@backgroundColor]
        inc eax
        add [@@xPixel], CHAR_WIDTH
        call drawRectangle, [@@xPixel], [@@yPixel], CHAR_SPACING, CHAR_HEIGHT, [@@backgroundColor]
        add [@@xPixel], CHAR_SPACING
        jmp @@loopString

    @@return:
        ; Return the x- and y-coordinates of the right bottom of the string text box (incl. padding).
        ; Coloring the padding.
        call drawRectangle, [@@xPixel], [@@yPixel], CHAR_PADDING, CHAR_HEIGHT, [@@backgroundColor]  ; Fill right padding with backgroundcolor.
        add [@@xPixel], CHAR_PADDING
        pop eax             ; eax = initial x-coordinate
        mov edx, [@@xPixel] ; edx = current x-coordinate
        sub edx, eax        ; edx = width of the string text box (incl. padding)
        pop ebx             ; ebx = initial y-coordinate
        call drawRectangle, eax, ebx, edx, CHAR_PADDING, [@@backgroundColor]                        ; Fill top padding with backgroundcolor.
        add [@@yPixel], CHAR_HEIGHT
        call drawRectangle, eax, [@@yPixel], edx, CHAR_PADDING, [@@backgroundColor]                 ; Fill bottom padding with backgroundcolor.
        add [@@yPixel], CHAR_PADDING
        mov eax, [@@xPixel]
        mov ebx, [@@yPixel]
        ret

endp drawString


proc drawCharacter
    arg @@char:dword, @@xPixel:dword, @@yPixel:dword, @@color:dword, @@backgroundColor:dword
    uses eax, ebx, edx

    ; Indexing the asciiArray at the ASCII value of the character.
    mov eax, [@@char]
    mov ebx, BYTES_PER_CHAR
    mul ebx
    add eax, offset asciiArray

    ; Clearing the backgrond
    call drawRectangle, [@@xPixel], [@@yPixel], CHAR_WIDTH, CHAR_HEIGHT, [@@backgroundColor]

    ; Drawing the character
    call drawBitmap, eax, [@@xPixel], [@@yPixel], CHAR_WIDTH, CHAR_FULL_SIZE, [@@color]
    
    ret
endp drawCharacter

proc getTime
    uses ebx, edx

    mov ah, 2Ch
    int 21h             ; Interrupt to get system time
    push edx            ; Push seconds to stack
    mov ebx, 60

    movzx eax, ch       ; Hours to eax, converting to seconds
    mul ebx
    mul ebx
    push eax

    movzx eax, cl       ; Minutes to eax, converting to seconds
    mul ebx
    pop ebx             ; Pop the seconds of the hours
    add eax, ebx        ; Add seconds of the hours to the seconds of the minutes

    pop edx             ; Pop the seconds of the stack
    movzx ebx, dh       
    add eax, ebx        ; Add seconds of the original time to the calculated seconds from hours and minutes

    ; Total seconds since midnight now obtained in eax

    ret
endp getTime

proc writeNumberToAsciiBuffer
    arg @@number:dword, @@size:dword, @@dataBuffer:dword
    uses eax, ecx, edx, ebx, edi

    mov ecx, 0
    mov edi, [@@dataBuffer]
    add edi, [@@size]
    dec edi                 ; edi now points to the last character of the buffer
    @@writeDigit:
        cmp ecx, [@@size]
        je @@return
        inc ecx
        mov ebx, 10
        mov eax, [@@number]
        xor edx, edx
        div ebx             ; Digit to be written is in edx (remainder of division!)
        mov [@@number], eax
        add edx, 48         ; Convert digit to ascii
        mov [edi], dl       ; Write digit to buffer
        dec edi
        jmp @@writeDigit
    
    @@return:
    ret

endp writeNumberToAsciiBuffer

proc secondsToTimeStamp
    arg @@seconds:dword, @@dataBuffer:dword
    uses eax, ebx, edx, edi

    mov eax, [@@seconds]
    mov ebx, 60     
    xor edx, edx        
    div ebx                 ; Dividing seconds by 60
                            ;   => minutes in eax, seconds in edx

    mov edi, [@@dataBuffer]
    call writeNumberToAsciiBuffer, eax, 2, edi
    add edi, 2
    mov [byte ptr edi], ':'
    add edi, 1
    call writeNumberToAsciiBuffer, edx, 2, edi
    
    ret
endp secondsToTimeStamp

proc updateTimers
    uses eax, ebx, edx

    cmp [winner], 2
    jne @@return
    cmp [currentTurn], 0
    je @@whiteTurn
    mov ebx, [blackLastTime]
    mov eax, offset blackTimer
    mov edx, offset blackTimerText
    jmp @@updateTimer
    @@whiteTurn:
    mov ebx, [whiteLastTime]
    mov eax, offset whiteTimer
    mov edx, offset whiteTimerText
    
    @@updateTimer:
    push edx
    push eax
    push ebx
    call getTime                    ; eax = current time
    mov ebx, [startTime]            ; ebx = time when current turn started
    sub eax, ebx                    ; eax = time elapsed since current turn started
    pop ebx                         ; ebx = time left when current turn started
    sub ebx, eax                    ; ebx = time left
    pop eax                         ; eax = address of timer
    mov [eax], ebx
    cmp ebx, 0
    jle @@lost
    jmp @@drawTimeStamp

    @@lost:
        mov [eax], 0            ; Making sure the value is set zero and not to a negative value.
        mov dl, [currentTurn]
        xor dl, 1
        mov [winner], dl        ; The opponent is the winner


    @@drawTimeStamp:
        pop edx
        call secondsToTimeStamp, ebx, edx
    
    @@return:
    ret
endp updateTimers

proc initializeTimers
    uses eax, ebx
    
    call getTime
    mov ebx, offset startTime
    mov [ebx], eax
    call secondsToTimeStamp, PLAY_TIME, offset whiteTimerText
    call secondsToTimeStamp, PLAY_TIME, offset blackTimerText

    ret
endp initializeTimers

proc updateInformation
    uses eax, ebx
    local @@whiteBackground:dword, @@blackBackground:dword

    call updateTimers

    cmp [winner], 2
    jne @@determineWinner
    ; Determine the colours based on the current turn.
    cmp [currentTurn], 0
    je @@whiteTurn
    mov [@@whiteBackground], 0FFh
    movzx eax, [turnColor]
    mov [@@blackBackground], eax
    jmp @@continue
    @@whiteTurn:
        movzx eax, [turnColor]
        mov [@@whiteBackground], eax
        mov [@@blackBackground], 0FFh
        jmp @@continue

    @@determineWinner:
        cmp [winner], 0
        movzx eax, [winnerColor]
        je @@whiteWinner
        ; Black wins
        mov [@@whiteBackground], 0FFh
        mov [@@blackBackground], eax
        jmp @@continue
        @@whiteWinner:
            ; White wins
            mov [@@whiteBackground], eax
            mov [@@blackBackground], 0FFh
        



    @@continue:
    call drawString, offset whiteString, FIELDDIMENSION, 0, 0Fh, 0FFh
    call drawString, offset whiteTimerText, FIELDDIMENSION, TEXT_HEIGHT, 0Fh, [@@whiteBackground]
    cmp [winner], 0
    jne @@drawBlackSection
    call drawString, offset wonString, eax, TEXT_HEIGHT, [@@whiteBackground], 0FFh

    @@drawBlackSection:
    call drawString, offset blackString, FIELDDIMENSION, (FIELDDIMENSION - TEXT_HEIGHT - TEXT_HEIGHT), 0Fh, 0FFh
    call drawString, offset blackTimerText, FIELDDIMENSION, (FIELDDIMENSION - TEXT_HEIGHT), 0Fh, [@@blackBackground]
    cmp [winner], 1
    jne @@return
    call drawString, offset wonString, eax, (FIELDDIMENSION - TEXT_HEIGHT), [@@blackBackground], 0FFh

    @@return:
    ret
endp updateInformation

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
proc mouseHandler
    uses eax, ebx, ecx, edx

    ; We update the lastMouseX and lastMouseY variables. When the frame buffer is drawn again, these values will be used.
    ; The x-coordinate is stored in cx, and the y-coordinate is stored in dx.
    ; Since the lastMouseX and lastMouseY store dwords, we make sure the cx and dx registers are zero-extended to 32 bits using movzx.
    movzx ecx, cx
    movzx edx, dx
    mov [lastMouseX], ecx
    mov [lastMouseY], edx
    
    ; We check if the left mouse button is pressed. If this is the case, we update the selected cell.
    and bl, 3
    jz @@return
    call selectCell, ecx, edx

    @@return:
        call drawBoard
        call transferFrame
        ret
endp mouseHandler

proc main
	sti
	cld

	push ds
	pop	es 

    mov ah, 02h
    int 1ah

    mov ah, 02h
    int 1ah

    mov ah, 02h
    int 1ah


	; set video mode, init registers
    call setupVideo
    
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

    ; Load the fonts from the bitmap file.
    call loadFont
    ; Load the pieces from the bitmap files and draw the board with pieces.
    call loadPieces
    call drawBoard

    call initializeTimers
    call transferFrame

    ; TEST CASE
    mov eax, (24 * 2) + 5
    mov ebx, (24 * 6) + 5
    call selectCell, eax, ebx
    mov eax, (24 * 2) + 5
    mov ebx, (24 * 4) + 5
    call selectCell, eax, ebx
    mov eax, (24 * 3) + 5
    mov ebx, (24 * 4) + 5
    call selectCell, eax, ebx
    mov eax, (24 * 2) + 5
    mov ebx, (24 * 5) + 5
    call selectCell, eax, ebx
    ;mov eax, 5
    ;mov ebx, 5
    ;call selectCell, eax, ebx
    ;mov eax, 5
    ;mov ebx, 25
    ;call selectCell, eax, ebx
    
    @@animation_loop:
    
        call updateInformation
        call transferFrame
        ; If the ESC key is pressed, the program is terminated.
        xor al, al
        mov	ah, 01h
        int	16h
        cmp	al, 1Bh
        je	@@finish
        jmp @@animation_loop
    

    @@finish:
        call mouse_uninstall
        call terminateProcess



endp main



; -------------------------------------------------------------------
; DATA
; -------------------------------------------------------------------
DATASEG
    
    ; Each chess piece is encoded in a word. The format is as follows (where B represents a bit):
    ;       B   B   BBBB   BBB   BBB
    ;       |   |     |     |     |
    ;      (1) (2)   (3)   (4)   (5)
    ;
    ; (1):  ALIVE
    ; (2):  PLAYER
    ;       0 = white
    ;       1 = black
    ; (3):  PIECE TYPE
    ;       0000 until 0111     = pawns
    ;       1000 and 1001       = rooks
    ;       1010 and 1011       = knights
    ;       1100 and 1101       = bishops
    ;       1110                = queen
    ;       1111                = king
    ; (4):  X-COORDINATE
    ; (5):  Y-COORDINATE
    
    pieces  dw 101000000000b, 101010001000b, 101100010000b, 101110011000b, 101111100000b, 101101101000b, 101011110000b, 101001111000b
            dw 100000000001b, 100001001001b, 100010010001b, 100011011100b, 100100100001b, 100101101001b, 100110110001b, 100111111001b
            dw 111000000111b, 111010001111b, 111100010111b, 111110011111b, 111111100111b, 111101101111b, 111011110111b, 111001111111b
            dw 110000000110b, 110001001110b, 110010010110b, 110011011110b, 110100100110b, 110101101110b, 110110110110b, 110111111110b


    ; When a player makes a move that opens the possibility of an en passant capture, the en passant state is modified.
    ;       BBB   BBB   B   B
    ;       |     |     |   |
    ;      (1)   (2)   (3) (4)
    ;
    ; (1):  x-coordinate of the en passant cell (jumped over by the player)
    ; (2):  y-coordinate of the en passant cell (jumped over by the player)
    ; (3):  direction of the piece that can be captured en passant
    ;       0 = above
    ;       1 = below
    ; (4):  en passant possible
    enPassantState dd 0

    framebuffer db 64000 dup (0)
    selectedcell dd 1
    leftcellvisible dw 0
    rightcellvisible dw 0
    fontfilename db "GUI\FONT.BIN", 0
    ;fontarray db FONTFILE_SIZE dup (?)
    

    asciiFileName db "bitmaps/5x5.bin", 0
    pionFileName db "bitmaps/pawn.bin", 0
    kingFileName db "bitmaps/king.bin", 0
    queenFileName db "bitmaps/queen.bin", 0
    bishopFileName db "bitmaps/bishop.bin", 0
    knightFileName db "bitmaps/knight.bin", 0
    rookFileName db "bitmaps/rook.bin", 0


    turnColor db 03h
    whiteColor db 42h
    blackColor db 06h

    whitePieceColor db 0Fh
    blackPieceColor db 00h

    winnerColor db 02h

    startTime dd 0
    whiteLastTime dd PLAY_TIME
    blackLastTime dd PLAY_TIME
    whiteTimer dd PLAY_TIME
    blackTimer dd PLAY_TIME

    whiteTimerText db "00:00", 0
    blackTimerText db "00:00", 0

    lastMouseX dd 0
    lastMouseY dd 0

    msgMissingMouse db 'Mouse missing! Terminating ...', 13, 10, '$'

    selectedCellX db 8
    selectedCellY db 8
    prevSelectedCellX db 8
    prevSelectedCellY db 8

    currentTurn db 1
    winner db 2        ; 2 = undecided, 0 = white, 1 = black

    whiteString db "WHITE", 0
    blackString db "BLACK", 0
    turnString db "->", 0

    wonString db "WON", 0
    lostString db "LOST", 0

    emptryString db 0

UDATASEG

    asciiArray db ASCII_FONT_BYTES dup (?)

    pionArray dd DWORDS_PER_PIECE dup (?)
    rookArray dd DWORDS_PER_PIECE dup (?)
    knightArray dd DWORDS_PER_PIECE dup (?)
    bishopArray dd DWORDS_PER_PIECE dup (?)
    queenArray dd DWORDS_PER_PIECE dup (?)
    kingArray dd DWORDS_PER_PIECE dup (?)
    

; -------------------------------------------------------------------
; STACK
; -------------------------------------------------------------------
STACK 100h

END main

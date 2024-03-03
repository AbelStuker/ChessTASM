# ChessTASM
University project (2nd bachelor): Chess game in Assembly language (TASM)

## Run the program
In DosBox, simply run the
``
CHESS
`` command to start the game.

## Features
- FIDE allowed movement restriction
  - Castling (not compliant with FIDE rules, also allowed after initial Rook move)
  - En passant
- Scenario loading
- Game saving
- Timers (default. 10 min) with turn indicator
  - Can be increased with 5min periods
- Pawn promotion (promotable to Queen, Bishop, Knight, Rook)

## Auxiliary files
In the ``auxiliary/``folder, some useful scripts can be found.
- Script ``bitmap_generator/stringtobitmap.c`` with executable ``stb``
  - Use this to convert a raw string of ones and zeroes into a bitmap. Chess piece images are bitonal (1-bit encoded), where a 0 pixel means transparent and a 1 pixels an unspecified colour (this allows for multiple colour variants of the same shape). Note that the bitmaps only contain the sequential bits of the image; no size information is stored!
- Script ``font_generator/generate_ascii_bitmap.c`` with executable ``gen_font``
  - In order to generate a font that can be used by the program, we need a bitmap that contains the entire font. Starting with a folder containing a bitmap of all the wanted ASCII-characters, this script converts all those bitmaps into 1 font bitmap. When $S$ is the size (in bytes) of a single-character bitmap and $C$ the value of a decimal ASCII-value. A bitmap with the name ``C.bin`` will then be encoded into the large bitmap starting at position $S*C$.
  
## Not yet implemented (and probably never will be)
- Checkmate detection (explicitly killing the King is necessary to win)
- Colour palette picker

![image](https://github.com/AbelStuker/ChessTASM/assets/62062732/7437ee0b-bafa-4f86-a328-8dca5f1bf8ea)

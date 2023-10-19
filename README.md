# Intel8086ChessASM

## Schaakstukken
Ik stel voor dat we deze schaakstukken van op het internet gebruiken om om te zetten in bitmaps: ![schaakstukken](https://upload.wikimedia.org/wikipedia/commons/thumb/b/b2/Chess_Pieces_Sprite.svg/800px-Chess_Pieces_Sprite.svg.png)We moeten wel nog bekijken of we die wel mogen gebruiken (met copyright enzo). Als dat niet het geval zou zijn moeten we er andere zoeken.



Afbeeldingen van schaakstukken kunnen we op basis van grijswaarden omzetting naar een monochrome bitmap.
1. Omzetten van .png bestand [naar nullen en enen](https://www.dcode.fr/binary-image#f1) (op basis van gekozen b/w threshold).
2. Het omzetten van deze nullen en enen [naar een .bit file](https://www.dcode.fr/file-data).

Elke 1 is een ingekleurde pixel en de 0 een transparante pixel. Hierdoor kunnen we a.d.h.v. dezelfde bitmap zowel de witte als de zwarte schaakstukken tekenen. De bitmap dimensies worden ingesteld op 32x32 bits, maar dat moeten we misschien nog aanpassen.

Elke bitmap in het project moet bij het opstarten van het spel worden gebuffered, zodat we maar 1 keer het bestand van elk stuk moeten uitlezen. Vervolgens kunnen we dan om elk stuk te tekenen gewoon de bijhorende databuffer uitlezen. 
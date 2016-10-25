
.enum $c380 export
CompressionTypeDataIndex  db ; $c380 Index into current byte at CompressionTypeData
TileCounter               dw ; $c381 Tile counter
CompressionTypeData       dw ; $c383 Pointer to tile compression type data (bit pairs)
RawTileData               dw ; $c385 Pointer to uncompressed tile data
Unused                    dsb 9
BlankTileBuffer           dsb 32 ; $c3a0 A blank tile, need not be in RAM really
TileBuffer                dsb 32 ; $c3c0 Staging area for the tile
.ende

DecompressTiles: ; $3ffd
  ; VRAM address must be set before calling!
  ; hl points to data
  ;
  ; Data format:
  ; Unused                dw ; Alwaya $0001
  ; TileCount             dw ; Number of tiles to decompress
  ; CompressedDataOffset  dw ; Normally points to after TileData
  ; TileData              dsb <n> ; Tile data bytes
  ;
  ; at start+offset:
  ; compressionTypes dsb <m> right-to-left packed 2-bit compression types:
  ; 00 = emit a zero tile
  ; 01 = emit a raw tile (next 32 bytes from TileData)
  ; 02 = emit a zero-packed tile (see below)
  ; 03 = emit a zero-packed bit-scrambled tile (same as 02 except with some post-processing)
  ;
  ; Zero packing stores 32 bytes as 32 bits + n bytes
  ; where the 32 bits are the right-to-left flags for whether to emit a 0 (0) or one of the n bytes (1)
  ; So it saves data when there are 3 or more zero bytes in the tile
  ;
  ; bit-scrambling xors bytes against each other in a weird way. Presumably this is to increase the number of 0 bits.
  ;
  ; RAM used:
  ; c380 db Compression type data bit-pair index (0-3)
  ; c381 dw Compression data bit-pair counter
  ; c383 dw Pointer to bit-pairs
  ; c385 dw Data pointer after header read
  ; c387...c38f unused
  ; c3a0 dsb 32 Zero buffer - not used?
  ; c3c0 dsb 32 Buffer for data to go to VRAM
  ;
  ; Tiles at (not exhaustive):
  ; $0b08b Menu screen
  ; $0cc00 Enemies
  ; $0db27 Enemies
  ; $10000 Title screen
  ; $14000 Pause status tiles
  ; $14364 Trampolines
  ; $15661 Splash screen
  ; $15fa7 Game Over screen
  ; $182cf Game tiles
  ; $191b8 Game tiles
  ; $194cc Game tiles

    push hl                               ; 003FFD E5
      inc hl                              ; 003FFE 23           ; Skip first two bytes
      inc hl                              ; 003FFF 23
      ld a,(hl)                           ; 004000 7E
      ld (TileCount),a                    ; 004001 32 81 C3     ; Store tile count to to RAM
      inc hl                              ; 004004 23
      ld a,(hl)                           ; 004005 7E
      ld (TileCount+1),a                  ; 004006 32 82 C3
      inc hl                              ; 004009 23
      ld e,(hl)                           ; 00400A 5E           ; Get compressed data offset
      inc hl                              ; 00400B 23
      ld d,(hl)                           ; 00400C 56
      inc hl                              ; 00400D 23
      ld (RawTileData),hl                 ; 00400E 22 85 C3     ; Save pointer
    pop hl                                ; 004011 E1   
    add hl,de                             ; 004012 19           ; Add offset to original pointer
    ld (CompressionTypeData),hl           ; 004013 22 83 C3     ; Save it
    
    ld hl,BlankTileBuffer                 ; 004016 21 A0 C3     ; Set BlankTileBuffer to 0
    ld de,BlankTileBuffer+1               ; 004019 11 A1 C3   
    ld bc,32-1                            ; 00401C 01 1F 00   
    ld (hl),$00                           ; 00401F 36 00    
    ldir                                  ; 004021 ED B0    
    
    xor a                                 ; 004023 AF   
    ld (TileDataIndex),a                  ; 004024 32 80 C3     ; Initialise index
    
Loop:   
    call GetCompressionType               ; 004027 CD DE 40     ; Get compression type (2 bits)
    cp $00                                ; 00402A FE 00
    jp nz,+                               ; 00402C C2 35 40
    ; Type 0
    call BlankTile                    ; 00402F CD 0B 41
    ; Note that it's emitted too
    jp ++                                 ; 004032 C3 5A 40

+:  cp $02                                ; 004035 FE 02
    jp nz,+                               ; 004037 C2 43 40
    ; Type 2: unpack with zero optimisation, then emit
    call ZeroPackedTileToBuffer           ; 00403A CD 79 40
    call TileToVRAM                       ; 00403D CD 16 41
    jp ++                                 ; 004040 C3 5A 40
    
+:  cp $03                                ; 004043 FE 03
    jp nz,+                               ; 004045 C2 54 40
    ; Type 3: unpack with zero optimisation, then xor, then emit
    call ZeroPackedTileToBuffer           ; 004048 CD 79 40
    call UnscrambleBits                   ; 00404B CD AD 40
    call TileToVRAM                       ; 00404E CD 16 41
    jp ++                                 ; 004051 C3 5A 40

+:  ; Type 1: raw tile
    call RawTileToBuffer                  ; 004054 CD 67 40
    call TileToVRAM                       ; 004057 CD 16 41
    ; Fall through
    
++: ld hl,(TileCounter)                   ; 00405A 2A 81 C3     ; Decrement counter
    dec hl                                ; 00405D 2B
    ld (TileCounter),hl                   ; 00405E 22 81 C3
    ld a,l                                ; 004061 7D
    or h                                  ; 004062 B4
    jp nz,Loop ; $4027                    ; 004063 C2 27 40     ; Loop until 0
    ret                                   ; 004066 C9   
    
RawTileToBuffer: ; 4067   
    ld bc,32                              ; 004067 01 20 00     ; Counter for 32 bytes
    ld hl,(RawTileData)                   ; 00406A 2A 85 C3     ; Raw data pointer
    ld de,TileBuffer                      ; 00406D 11 C0 C3     ; Copy to VRAM buffer
    ld bc,32                              ; 004070 01 20 00     ; Whoops, did it twice
    ldir                                  ; 004073 ED B0    
    ld (RawTileData),hl                   ; 004075 22 85 C3     ; Save new pointer
    ret                                   ; 004078 C9

ZeroPackedTileToBuffer: ; 4079
    ld ix,TileBuffer                      ; 004079 DD 21 C0 C3  ; Destination (VRAM buffer)
    ld hl,(RawTileData)                   ; 00407D 2A 85 C3     ; Seurce
    ld e,(hl)                             ; 004080 5E           ; Read 32 bits
    inc hl                                ; 004081 23
    ld d,(hl)                             ; 004082 56
    inc hl                                ; 004083 23
    ld c,(hl)                             ; 004084 4E
    inc hl                                ; 004085 23
    ld b,(hl)                             ; 004086 46
    inc hl                                ; 004087 23
    ld a,32                               ; 004088 3E 20        ; Bit counter
-:  push af                               ; 00408A F5
      rr b                                ; 00408B CB 18        ; Rotate bcde right
      rr c                                ; 00408D CB 19
      rr d                                ; 00408F CB 1A
      rr e                                ; 004091 CB 1B
      jp c,+                              ; 004093 DA 9D 40     ; 0 -> emit 0, 1 -> emit a byte from hl
      ld (ix+$00),$00                     ; 004096 DD 36 00 00
      jp ++                               ; 00409A C3 A2 40
+:    ld a,(hl)                           ; 00409D 7E
      ld (ix+$00),a                       ; 00409E DD 77 00
      inc hl                              ; 0040A1 23
++:   inc ix                              ; 0040A2 DD 23
    pop af                                ; 0040A4 F1
    dec a                                 ; 0040A5 3D
    jp nz,-                               ; 0040A6 C2 8A 40
    ld (RawTileData),hl                   ; 0040A9 22 85 C3
    ret                                   ; 0040AC C9

UnscrambleBits: ; 40ad
    ; XORs the data in the buffer against itself in a weird way
    ld ix,TileBuffer                      ; 0040AD DD 21 C0 C3  ; Point at the buffer
    ld b,7                                ; 0040B1 06 07        ; Counter for rows
-:  ld a,(ix+$00)                         ; 0040B3 DD 7E 00     ; xor bytes in the buffer against each other
    xor (ix+$02)                          ; 0040B6 DD AE 02     ; buf[i+2] ^= buf[i+0]
    ld (ix+$02),a                         ; 0040B9 DD 77 02
    ld a,(ix+$01)                         ; 0040BC DD 7E 01     ; buf[i+3] ^= buf[i+1]
    xor (ix+$03)                          ; 0040BF DD AE 03
    ld (ix+$03),a                         ; 0040C2 DD 77 03
    ld a,(ix+$10)                         ; 0040C5 DD 7E 10     ; buf[i+18] ^= buf[i+16]
    xor (ix+$12)                          ; 0040C8 DD AE 12
    ld (ix+$12),a                         ; 0040CB DD 77 12
    ld a,(ix+$11)                         ; 0040CE DD 7E 11     ; buf[i+19] ^= buf[i+17]
    xor (ix+$13)                          ; 0040D1 DD AE 13
    ld (ix+$13),a                         ; 0040D4 DD 77 13
    inc ix                                ; 0040D7 DD 23        ; Then move on by 2 bytes
    inc ix                                ; 0040D9 DD 23
    djnz -                                ; 0040DB 10 D6        ; And repeat 7 times
    ret                                   ; 0040DD C9

GetCompressionType: ; 40de
    ld a,(CompressionTypeDataIndex)       ; 0040DE 3A 80 C3     ; c380 = index of which bit pair to read, 0-3
    cp $04                                ; 0040E1 FE 04
    jp nz,+                               ; 0040E3 C2 F1 40
    ; Increment pointer
    ld hl,(CompressionTypeData)           ; 0040E6 2A 83 C3
    inc hl                                ; 0040E9 23
    ld (CompressionTypeData),hl           ; 0040EA 22 83 C3
    ; Reset counter
    xor a                                 ; 0040ED AF
    ld (CompressionTypeDataIndex),a       ; 0040EE 32 80 C3
    ; Fall through
+:  ld b,a                                ; 0040F1 47
    ld hl,(CompressionTypeData)           ; 0040F2 2A 83 C3     ; Get the byte
    ld a,(hl)                             ; 0040F5 7E
-:  dec b                                 ; 0040F6 05           ; Shift to the bits we want
    jp m,+                                ; 0040F7 FA FF 40
    rrca                                  ; 0040FA 0F
    rrca                                  ; 0040FB 0F
    jp -                                  ; 0040FC C3 F6 40
+:  and $03                               ; 0040FF E6 03        ; mask to two low bits
    push af                               ; 004101 F5
      ld a,(CompressionTypeDataIndex)     ; 004102 3A 80 C3   ; increment index
      inc a                               ; 004105 3C
      ld (CompressionTypeDataIndex),a     ; 004106 32 80 C3
    pop af                                ; 004109 F1
    ret                                   ; 00410A C9

BlankTile: ; 410b
    ld hl,BlankTileBuffer                 ; 00410B 21 A0 C3 ; Copy 32 bytes to VRAM buffer
    ld de,TileBuffer                      ; 00410E 11 C0 C3
    ld bc,32                              ; 004111 01 20 00
    ldir                                  ; 004114 ED B0
    ; fall through

TileToVRAM: ; 4116
    ld hl,TileBuffer                      ; 004116 21 C0 C3 ; Emit 32 bytes to VDP from VRAM buffer
    ld b,32                               ; 004119 06 20
-:  ld a,(hl)                             ; 00411B 7E
    out ($be),a                           ; 00411C D3 BE
    push hl                               ; 00411E E5
    pop hl                                ; 00411F E1
    inc hl                                ; 004120 23
    djnz -                                ; 004121 10 F8
    ret                                   ; 004123 C9

    ; Example data
/*
01 00 Ignored
00 01 256 tiles (?)
86 00 Data offset $86 (32*4+6)
   00 80 00 00 Tile 1 bitmask - only one non-zero byte
   FF          Tile 1 data
   00 80 00 00 Tile 2 bitmask
   FF          Tile 2 data
   00 80 08 00 Tile 3 bitmask
   F0 0F       Tile 3 data
   00 00 88 00 Tile 4 bitmask
   E0 1F       Tile 4 data
   00 80 88 08 Tile 5
   C0 30 0E 01 
   00 00 00 88 Tile 6
   F0 0F 
   00 88 00 00 Tile 7
   0F F0
   80 08 00 00 Tile 8
   1F E0
   00 30 00 00 Tile 9
   FF FF
   00 30 00 00 Tile 10
   FF FF 
   00 30 33 00 Tile 11
   F0 F0 0F 0F 0F 0F 
   00 00 33 03 Tile 12
   E0 E0 FF FF 1F 1F 
   00 30 33 33 Tile 13
   C0 C0 30 30 3E 3E 0F 0F 01 01 
   00 00 00 33 Tile 14
   F0 F0 FF FF 
   00 33 00 00 Tile 15
   0F 0F FF FF 
   30 33 00 00 Tile 16
   1F 1F FF FF E0 E0 
   00 60 06 00 Tile 17
   C0 C0 20 20
AA AA FF FF 02 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
Bit pairs:
2 2 2 2 2 2 2 2 3 3 3 3 3 3 3 3 2 0 0 0 ...
*/
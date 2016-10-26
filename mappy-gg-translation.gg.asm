.memorymap
defaultslot 0
slotsize $4000
slot 0 $0000
slot 1 $4000
slot 2 $8000
.endme

.define BankCount 128/16 ; Original rom is 128KB

.rombankmap
bankstotal BankCount
banksize $4000
banks BankCount
.endro

; Load in the ROM to patch
.background "Mappy (JP).gg"
.emptyfill $ff

; Add SDSC header. This fixes the checksum but also sets the region code to SMS...
.sdsctag 1.10, "Mappy English translation", "", "Maxim"

; Let's mark unused areas as free
.unbackground $00006 $00037
.unbackground $07fd9 $07fff ; Space for a header...
;.unbackground $0bc61 $0bfff
;.unbackground $0fc26 $0ffff
;.unbackground $13be0 $13fff
.unbackground $16f91 $17fff ; 4207 bytes
;.unbackground $1bc7d $1bfff
;.unbackground $1eb5c $1ffff ; 5284 bytes

; Let's also mark the old tiles as unused
;.unbackground $0b08b $0b92d ; 876 bytes
; and the code
;.unbackground $0097a $00987 ; 14 bytes

.bank 0 slot 0
.org $973
.section "hook" overwrite
;    xor    a               ; 000973 AF 
;    out    ($bf),a         ; 000974 D3 BF 
;    ld     a,$40           ; 000976 3E 40 
;    out    ($bf),a         ; 000978 D3 BF 
;    ; Load data
;    ld     hl,$b08b        ; 00097A 21 8B B0 
;    ld     a,$02           ; 00097D 3E 02 
;    call   $4124           ; 00097F CD 24 41 ; Paging
;    call   $3ffd           ; 000982 CD FD 3F ; Decode tiles
;    call   $4134           ; 000985 CD 34 41 ; Restore paging
;    ; Tilemap:
;    ld     a,$04           ; 000988 3E 04 
;    call   $4124           ; 00098A CD 24 41 ; Paging
;    ld     hl,$3a12        ; 00098D 21 12 3A ; Destination VRAM address
;    ld     de,$b2e6        ; 000990 11 E6 B2 ; Source data
;    call   $4b2e           ; 000993 CD 2E 4B ; Load
;    call   $4134           ; 000996 CD 34 41 ; Restore paging
;    call   $3bbf           ; 000999 CD BF 3B ; Screen on?

  ld a,:aPLib_decompress
  call $4124  ; Paging
  ld de,$4000
  ld hl,tiles
  call aPLib_decompress
  ld de,$7800
  ld hl,tilemap
  call aPLib_decompress
  call $4134  ; Restore paging
  jp $999 ; back to normal flow
.ends

.slot 2

.section "Tiles" superfree
tiles:
.incbin "tiles.aPLib"
tilemap:
.incbin "tilemap.aPLib"
.define aPLibToVRAM
.define aPLibMemory $c3a0
.include "aPLib decompressor.asm"
.ends

.bank 6 slot 2
.macro skip args n
  .db $fe n 0
.endm
.macro square
  .db \1,\2
  skip 30
  .db \3,\4
.endm
.orga $bbed
.section "Carrot position 1" overwrite
  square 1,2,3,4
  skip 30+32
  square 0,0,0,0
  skip 30+32
  square 0,0,0,0
.ends
.orga $bc09
.section "Carrot position 2" overwrite
  square 0,0,0,0
  skip 30+32
  square 1,2,3,4
  skip 30+32
  square 0,0,0,0
.ends
.orga $bc25
.section "Carrot position 3" overwrite
  square 0,0,0,0
  skip 30+32
  square 0,0,0,0
  skip 30+32
  square 1,2,3,4
.ends

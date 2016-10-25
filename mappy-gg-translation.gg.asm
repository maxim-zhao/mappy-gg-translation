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

.background "Mappy (JP).gg"
.emptyfill $ff

; Let's mark unused areas as free
.unbackground $00006 $00037
;.unbackground $07fe9 $07fef
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
.org $97a
.section "hook" overwrite
;    ld     hl,$b08b        ; 00097A 21 8B B0 
;    ld     a,$02           ; 00097D 3E 02 
;    call   $4124           ; 00097F CD 24 41 ; Paging
;    call   $3ffd           ; 000982 CD FD 3F ; Decode tiles
;    call   $4134           ; 000985 CD 34 41 ; Restore paging
.define returnpoint $0988
  jp hack
.ends

.section "hack" free
hack:
  ld a,:PSG_decompress
  call $4124 ; paging
  ld hl,$4000
  ld ix,tiles
  call PSG_decompress
  call $4134 ; restore paging
  jp returnpoint
; Fill with zero to minimise diffs
.dsb 29 0
.ends


.slot 2

.section "Tiles" superfree
tiles:
.incbin "tiles-translated.psgcompr"
.define PSGDecoderBuffer $c3a0
.include "Phantasy Star Gaiden decompressor.asm"
.ends

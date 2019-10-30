*=$0801
  !byte $0c,$08,$0a,$00,$9e,$20,$32,$33,$30,$34,$00,$00,$00 ; basic auto start at $0900 

screen_color = $f7;
color = $f8;
color_h = $f9;
velocity = $fa;
cursor = $fb ; locations in screen memory
cursor_h = $fc
cursor_clear = $fd 
cursor_clear_h = $fe
bitmask_clear = $ff

x_pos = $1200 ; +32
x_pos_h = $1220 ; +32
y_pos = $1240 ; +32
cursor_buffer = $1260 ; + 32
cursor_buffer_h = $1280 ; + 32
bitmask_buffer = $12a0 ; + 32

size = 32

*=$0900
      jsr init     
      jsr blank_video
      jsr blank_screen
      jsr init_starfield
move_loop
      jsr draw_stars
      jsr move_stars
vsync_wait      
      lda $d012
      bne vsync_wait
      jmp move_loop
      
init
      lda $d018
      ora #$8 ; Set video base to 8192
      sta $d018 

      lda #0 ; color
      sta $d020; set border color
      lda $d011
      ora #$20 ; set high res mode
      sta $d011 
      rts
      
blank_video
      lda #$00
      sta cursor
      lda #$20
      sta cursor_h
      ldy #0      
videoloop
      lda #0
      sta (cursor), y
      iny
      bne videoloop ; loop unless high bit needs inc
      inc cursor_h
      lda cursor_h ; check end of range
      cmp #$40 ; 8000 bytes
      beq blank_screen ; finished
      jmp videoloop
      rts

blank_screen
      ldy #0
      lda #16
screenloop
      sta $0400, Y
      sta $0500, Y
      sta $0600, Y
      sta $0700, Y
      iny
      bne screenloop
      rts
      
init_starfield
      ldx #0
next_star
      jsr init_star
      inx
      cpx #size
      bcc next_star
      rts

draw_stars
      ldy #0
draw_star
      jsr plot_star ; Plot star index y, return with pixel bit index in x
      txa
      pha
      jsr set_color ; Set colour in screen memory using star at index y 
      pla
      tax
      lda cursor_buffer_h, y
      beq save_cursor ; Skip if buffer is empty
      sta cursor_clear_h
      lda cursor_buffer, y
      sta cursor_clear
      lda bitmask_buffer, y
      sta bitmask_clear
      tya
      pha
      ldy #0
      lda (cursor_clear), y
      and bitmask_clear ; clear star
      sta (cursor_clear), y
      pla
      tay
save_cursor
      lda cursor
      sta cursor_buffer, y ; store coordinate in buffer
      lda cursor_h
      sta cursor_buffer_h, y
      lda x_bit_clear, x
      sta bitmask_buffer, y ; store bitmask in buffer
      iny
      cpy #size
      bcc draw_star
      rts
      
move_stars
       ldx #0
move_next
       lda y_pos, x ; velocity of 1 or 2 based on y position
       and #%00000001
       clc
       adc #1
       sta velocity
       lda x_pos, x
       sec
       sbc velocity
       sta x_pos, x
       bcs continue_move
       lda x_pos_h, x
       beq new_star
       sbc #0
       sta x_pos_h, x
       jmp continue_move
new_star
       jsr regen_y
       lda #63 ; move x to pos 319
       sta x_pos, x
       lda #1
       sta x_pos_h, x
continue_move       
       inx
       cpx #size
       bcc move_next
       rts

plot_star
      ; Calculate y
      lda y_pos, y 
      lsr ; /8
      lsr
      lsr 
      ; * 320
      sta cursor_h ; high = y / 8 * 256
      sta cursor
      lda #0
      ldx #6; low = y / 8 * 64
y_low_mul
      asl cursor 
      rol 
      dex
      bne y_low_mul
      clc
      adc cursor_h
      sta cursor_h
      ; Add y mod 8
      lda y_pos, y
      and #%00000111
      clc
      adc cursor
      sta cursor
      lda cursor_h
      adc #0
      sta cursor_h
      ; Add x minus last 3 bits
      lda x_pos, y
      and #%11111000
      clc
      adc cursor
      sta cursor
      lda cursor_h
      adc x_pos_h, y
      sta cursor_h
      ; Lookup bit position based on last 3 bits
      lda x_pos, y 
      and #%00000111
      tax ; Lose contents of x
      lda cursor_h ; add video offset
      clc
      adc #$20 
      sta cursor_h
      tya
      pha
      ldy #0
      lda (cursor), y
      ora x_bit_set, x      
      sta (cursor), y
      pla
      tay
      rts

set_color
      lda y_pos, y ; / 8 
      lsr 
      lsr 
      lsr 
      tax
      lda y_screen_h, x ; Lookup *40 table
      sta color_h
      lda y_screen, x
      sta color
      lda x_pos_h, y ; / 8
      lsr ; (x < 320)
      lda x_pos, y
      ror
      lsr
      lsr
      clc
      adc color
      sta color
      lda #04 ; Add final carry and $0400
      adc color_h
      sta color_h
      lda y_pos, y ; Use low 4 bits for color
      asl 
      asl
      asl
      asl
      cmp #0
      bne save_color; Proceed for normal colors
      lda #16 ; Set black stars to white
save_color
      sta screen_color
      tya ; now set color in screen memory
      pha
      ldy #0
      lda (color), y
      and #%00001111
      ora screen_color
      sta (color), y
      pla
      tay

      rts
      
init_star ; generate new star at offset x
      lda #0
      sta x_pos_h, x
      jsr rnd
      lda $63
      sta x_pos, x
      lda $64
      and #%00111111 ; + 64
      clc
      adc x_pos, x
      sta x_pos, x
      lda #0
      adc x_pos_h, x
      sta x_pos_h, x
regen_y
      jsr rnd
      lda $63
      cmp #200
      bcs regen_y ; a >= 200
      sta y_pos, x
      rts
      
rnd ; call basic random generator, preserving x
      txa
      pha
      jsr $e09a
      pla
      tax
      rts
      
x_bit_set
      !byte $80,$40,$20,$10,$08,$04,$02,$01
x_bit_clear
      !byte $7F,$BF,$DF,$EF,$F7,$FB,$FD,$FE
y_screen ; *40 lookup for screen memory
      !byte $00,$28,$50,$78,$A0,$C8,$F0,$18
      !byte $40,$68,$90,$B8,$E0,$08,$30,$58
      !byte $80,$A8,$D0,$F8,$20,$48,$70,$98
      !byte $C0
y_screen_h
      !byte $00,$00,$00,$00,$00,$00,$00,$01
      !byte $01,$01,$01,$01,$01,$02,$02,$02
      !byte $02,$02,$02,$02,$02,$03,$03,$03
      !byte $03

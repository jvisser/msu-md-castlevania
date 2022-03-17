; MEMORY: ------------------------------------------------------------------------------------------

; Mega CD MMIO addresses used for communicating with msu-md driver on the mega cd (mode 1)
MSU_COMM_CMD        equ $a12010                 ; Comm command 0 (high byte)
MSU_COMM_ARG        equ $a12011                 ; Comm command 0 (low byte)
MSU_COMM_CMD_CK     equ $a1201f                 ; Comm command 7 (low byte)
MSU_COMM_STATUS     equ $a12020                 ; Comm status 0 (0-ready, 1-init, 2-cmd busy)

; Where to put the code
ROM_END             equ $fff60

; MSU COMMANDS: ------------------------------------------------------------------------------------------

MSU_PLAY            equ $1100                   ; PLAY      decimal no. of track (1-99) playback will be stopped in the end of track
MSU_PLAY_LOOP       equ $1200                   ; PLAY LOOP decimal no. of track (1-99) playback will restart the track when end is reached
MSU_PAUSE           equ $1300                   ; PAUSE     vol fading time. 1/75 of sec. (75 equal to 1 sec) instant stop if 0 pause playback
MSU_RESUME          equ $1400                   ; RESUME    none. resume playback
MSU_VOL             equ $1500                   ; VOL       volume 0-255. set cdda volume
MSU_NOSEEK          equ $1600                   ; NOSEEK    0-on(default state), 1-off(no seek delays)  seek time emulation switch
MSU_PLAYOF          equ $1a00                   ; PLAYOF    #1 = decimal no. of track (1-99) #2 = offset in sectors from the start of the track to apply when looping play cdda track and loop from specified sector offset

; VARIABLES: ------------------------------------------------------------------------------------------

stageMusic          equ $fffefc
currentMusic        equ $fffefe
musicOffset         equ $fffeff

; MACROS: ------------------------------------------------------------------------------------------

    macro MSU_WAIT
.\@
        tst.b   MSU_COMM_STATUS
        bne     .\@
    endm

    macro MSU_COMMAND cmd, param
        MSU_WAIT
        move.w  #(\1|\2),MSU_COMM_CMD           ; Send msu cmd
        addq.b  #1,MSU_COMM_CMD_CK              ; Increment command clock
    endm

; MEGA DRIVE OVERRIDES : ------------------------------------------------------------------------------------------

    ; M68000 Reset vector
    org     $0
    dc.l    stageMusic
    dc.l    EntryPoint                          ; Custom entry point for redirecting

    ; Original entry point
    org     $208
Game

    ; Original PlaySound sub routine
    org     $eb9bc
    jsr     PlaySound
    nop

    ; Main menu
    org     $35d6
    jsr     VarReset

    ; Map change
    org     $c256
    jsr     SetMapMusic

; MSU-MD Init: -------------------------------------------------------------------------------------

    org     ROM_END
EntryPoint
    bsr     AudioInit
    bsr     VarInit
    jmp     Game

    align   2

AudioInit
    bsr     MSUDriverInit
    tst.b   d0                                  ; if 1: no CD Hardware found
.audioInitFail
    bne     .audioInitFail                      ; Loop forever

    MSU_COMMAND MSU_NOSEEK, 1
    MSU_COMMAND MSU_VOL,    255
    rts

; Sound: -------------------------------------------------------------------------------------

    align   2

VarInit
    st      stageMusic
    st      currentMusic
    sf      musicOffset
    rts


VarReset
    bsr   VarInit
    jmp     $312d0


SetMapMusic
    move.b  d0,$ff90f8

    ; If stage music changed reset musicOffset
    cmp.b   stageMusic,d0
    beq     .sameMusic
        move.b  d0,stageMusic
        sf      musicOffset
.sameMusic
    rts


PlaySound
    ; Stop music?
    cmp.b   #$f2,d0
    bne     .checkPause

        MSU_COMMAND MSU_PAUSE, 0
        bra .noMusic

    ; TODO: f3/f4?

    ; Pause music
.checkPause
    cmp.b   #$f5,d0
    bne     .checkResume

        MSU_COMMAND MSU_PAUSE, 0
        move.b  #$f2,d0
        bra     .noMusic

    ; Resume music
.checkResume
    cmp.b   #$f6,d0
    bne     .checkMusic

        MSU_COMMAND MSU_RESUME, 0
        move.b  #$f2,d0
        bra     .noMusic

    ; Play music?
.checkMusic:
    cmp.b   #$d0,d0
    bls     .noMusic
    cmp.b   #$ef,d0
    bhi     .noMusic
        sub.b   #$d1,d0
        cmp.b   #18,d0
        beq     .areaBoss
        cmp.b   #29,d0
        beq     .death
        bra     .musicReady
.areaBoss
    ; Enable alternative music mode when mid boss music starts
    move.b  #2,musicOffset
    bra     .musicReady
.death
    ; If dying while fighting a mid boss reset alternative music mode
    cmp.b   #18,currentMusic
    bne     .musicReady
        sf      musicOffset
.musicReady
    move.b  d0,currentMusic

    ; Select cd track
    ext.w   d0
    add.w   d0,d0
    add.w   d0,d0
    add.b   musicOffset,d0
    move.w  AUDIO_TBL(pc,d0),d0

    ; Send MSU command
    MSU_WAIT
    move.w  d0,MSU_COMM_CMD
    addq.b  #1,MSU_COMM_CMD_CK

    ; Stop fm music
    move.b  #$f2,d0

.noMusic

    ; Original code
    bset.b  #0,$ff4011
    rts

; TABLES: ------------------------------------------------------------------------------------------

        align 2
AUDIO_TBL
        dc.w    MSU_PLAY|01,        MSU_PLAY|01             ; 01    - Konami Logo
        dc.w    MSU_PLAY|02,        MSU_PLAY|02             ; 02    - The Beating in Darkness (Title Theme)
        dc.w    MSU_PLAY_LOOP|03,   MSU_PLAY_LOOP|03        ; 03    - A Vision of Dark Secrets (Opening Theme)
        dc.w    MSU_PLAY_LOOP|04,   MSU_PLAY_LOOP|04        ; 04    - Bonds of Brave Men (Character Selection)
        dc.w    MSU_PLAY|05,        MSU_PLAY_LOOP|05        ; 05    - Arduous Journey (Map Theme)
        dc.w    MSU_PLAY_LOOP|06,   MSU_PLAY_LOOP|06        ; 06    - Mysterious Curse (Password)
        dc.w    MSU_PLAY|07,        MSU_PLAY|07             ; 07    - Reincarnated Soul, Part 1 (Introduction)
        dc.w    MSU_PLAY_LOOP|08,   MSU_PLAY_LOOP|09        ; 08,09 - Reincarnated Soul, Part 2 (Stage 1)
        dc.w    MSU_PLAY_LOOP|10,   MSU_PLAY_LOOP|11        ; 10,11 - The Sinking Old Sanctuary (Stage 2)
        dc.w    MSU_PLAY_LOOP|12,   MSU_PLAY_LOOP|13        ; 12,13 - The Discolored Wall (Stage 3)
        dc.w    MSU_PLAY_LOOP|14,   MSU_PLAY_LOOP|15        ; 14,15 - Iron-Blue Intention (Stage 4)
        dc.w    MSU_PLAY_LOOP|16,   MSU_PLAY_LOOP|17        ; 16,17 - The Prayer of a Tragic Queen (Stage 5)
        dc.w    MSU_PLAY_LOOP|18,   MSU_PLAY_LOOP|19        ; 18,19 - Calling From Heaven (Stage 6)
        dc.w    MSU_PLAY|22,        MSU_PLAY|22             ; 22    - Pressure (Invincibility)
        dc.w    MSU_PLAY_LOOP|23,   MSU_PLAY_LOOP|23        ; 23    - Beginning (Classic Tune 1)
        dc.w    MSU_PLAY_LOOP|24,   MSU_PLAY_LOOP|24        ; 24    - Bloody Tears (Classic Tune 2)
        dc.w    MSU_PLAY_LOOP|25,   MSU_PLAY_LOOP|25        ; 25    - Vampire Killer (Classic Tune 3)
        dc.w    MSU_PLAY_LOOP|26,   MSU_PLAY_LOOP|26        ; 26    - Nothing to Lose (Stage 1D)
        dc.w    MSU_PLAY_LOOP|27,   MSU_PLAY_LOOP|27        ; 27    - Messenger From Devil (Area Boss Theme)
        dc.w    MSU_PLAY_LOOP|28,   MSU_PLAY_LOOP|28        ; 28    - The Six Servants of the Devil (Stage Boss Theme)
        dc.w    MSU_PLAY_LOOP|29,   MSU_PLAY_LOOP|29        ; 29    - Theme of Simon (Classic Tune 4)
        dc.w    MSU_PLAY_LOOP|30,   MSU_PLAY_LOOP|30        ; 30    - The Vampire's Stomach (Final Boss Theme)
        dc.w    MSU_PLAY|31,        MSU_PLAY|31             ; 31    - Orb
        dc.w    MSU_PLAY_LOOP|32,   MSU_PLAY_LOOP|32        ; 32    - Energy Orb
        dc.w    MSU_PLAY|33,        MSU_PLAY|33             ; 33    - Stage Clear
        dc.w    MSU_PLAY|34,        MSU_PLAY|34             ; 34    - Dracula Orb
        dc.w    MSU_PLAY|35,        MSU_PLAY|35             ; 35    - All Clear
        dc.w    MSU_PLAY|36,        MSU_PLAY|36             ; 36    - Together Forever (Ending Theme)
        dc.w    MSU_PLAY|37,        MSU_PLAY|37             ; 37    - Requiem for the Nameless Victims (Staff Roll)
        dc.w    MSU_PLAY|20,        MSU_PLAY|20             ; 20    - Death
        dc.w    MSU_PLAY|21,        MSU_PLAY|21             ; 21    - After the Good Fight (Game Over)
AUDIO_TBL_END

; MSU-MD DRIVER: -----------------------------------------------------------------------------------

        align 2
MSUDriverInit
        incbin  "msu-drv.bin"

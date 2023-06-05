# PIC12F675_IR_transmitter

uPD6121 IR protocol implementation (may be switched to classic NEC IR by changing first value into "F_IR_start" procedure)

GP0 - LED<br>
GP1 - Button1 (first command)<br>
GP2 - Button2 (second command)<br>
XT Osc 4Mhz<br>
Vdd - +3v<br>

At first, for making an IR transmitter with microcontroller, we need a 36-40kHz PWM.
Old models of PIC MCU (like PIC12F675 or PIC12F629) don't have hardware PWM at all, so we have to write software implementation by ourselves.
C language not suitable for this purpose due to the some "code garbage" that inevitably occurs when compiling, causing the delays to become so inaccurate that the required frequency cannot be reached. So it's better to use assembler, which gives full control over the microcontroller's resources and allows to generate correct delays.<br>
<br>
Yes, this code is not elegant, but if it works, it's not stupid.<br>
By the way, we don't need absolutely accurate timings, they can be a little bit floating.

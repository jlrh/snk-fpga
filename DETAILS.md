# snk-fpga

🇬🇧 English (below) · [🇪🇸 Español](#español)

FPGA recreations of **SNK** arcade boards, built on the **JTFRAME** framework (GPLv3). MiSTer target.

> ℹ️ Independent project — **NOT** an official jotego core. Built on his GPLv3 JTFRAME framework.

## Cores

### Guerrilla War (SNK, 1987)
Vertical run-and-gun on the SNK "triple Z80" hardware (A6003/A6004 boards). Hardware: **three Z80** CPUs at 4 MHz
(main and sub share all their RAM and sync through cross NMIs; the third drives the sound) + **YM3526** (OPL) +
**Y8950** (OPL + ADPCM voices) + the SNK video customs **SNK8601 / SNK8602**, written from scratch for this core:
a 512×512 scrolling background of 16×16 tiles, an 8×8 text layer, and 96 sprites (64 of 16×16 and 32 of 32×32)
drawn in three priority passes. The colour comes from three 4-bit PROMs. The **Y8950 ADPCM channel**, not available
in any existing FPGA module, was written for this core and matches MAME sample by sample. 400×224 (vertical).

**Status: playable on MiSTer** — tested on hardware (boot, coins, controls, sound effects). In simulation the video
matches MAME pixel-for-pixel in 225 of 225 reference scenes (boot, attract, gameplay and flipped screen); the sound
CPU follows MAME's sound commands (99.6 % of the YM register writes match in order over 2300 frames, and the voices
fire on the same frame), and the Y8950 ADPCM output equals MAME's in 3.3 million samples.

**Rotary joystick:** the original uses a 12-position rotary stick. Buttons 3 and 4 turn the aim left/right (hold to
keep turning). **Known limitation:** the real video timing of the SNK8601/8602 is not documented; the core uses an
8 MHz pixel clock, 512×264 (15.625 kHz / 59.19 Hz), while MAME uses a nominal 60 Hz.

A prebuilt `.rbf` is in [`releases/`](releases/) — **distributable**: all game ROMs are loaded at **runtime** from
the `.mra`; the bitstream bakes no game data. Or build from source (`cores/gwar/`). See [`BUILD.md`](BUILD.md).

### Mechanized Attack (SNK, 1989)
Two-player light-gun shooter on the SNK A8002 board. Hardware: **68000** at 12 MHz + **Z80** at 4 MHz for the sound +
**YM2608** (OPNA: 6 FM channels, SSG, rhythm and ADPCM-B voices), two 16×16 scrolling playfields of 256×32 tiles, an
8×8 text layer and a zooming sprite generator (sprites of 16 to 128 pixels scaled through a ROM table). The video is
shared with Beast Busters. No FPGA YM2608 existed: the **rhythm section and the ADPCM-B channel** were written for this
core and match MAME's ymfm sample by sample; the FM and SSG parts reuse JT12. 256×224 (horizontal).

**Status: playable on MiSTer** — tested on hardware (boot, coins, a full game, graphics, music and effects, light guns
with a GunCon 3). In simulation the video matches MAME pixel-for-pixel in 149 of 149 reference scenes (title,
attract and a full game, ~30 000 frames), and the sound CPU follows MAME's sound commands: the writes to the YM2608 match MAME over 900 frames,
apart from two timer-flag acknowledgements one poll apart.

**Light guns:** two guns through MiSTer's light-gun support (mouse, Sinden, Gun4IR, GunCon or analog stick), with an
on-screen crosshair. Calibrate inside the core (OSD → *Define joystick buttons* → F10). Trigger = button 1,
grenade = button 2. **Known limitations:** the real video timing of the board is not documented; the core uses a
6 MHz pixel clock, 384×264 (15.6 kHz / 59.2 Hz), while MAME uses a nominal 60 Hz. The gun recoil solenoids are not
driven.

A prebuilt `.rbf` is in [`releases/`](releases/) — **distributable**: all game ROMs, including the YM2608 internal
rhythm ROM (`ym2608.zip`), are loaded at **runtime** from the `.mra`. Or build from source (`cores/mechatt/`, plus the
shared video in `cores/bbusters/hdl/`). See [`BUILD.md`](BUILD.md).

## Build

This repo contains **only the core code** (`cores/<core>/`). The framework and third-party modules (jtframe, jtopl,
jt12) are **not included**. Quick version:

1. Clone [jtcores](https://github.com/jotego/jtcores) (brings jtframe + modules).
2. Copy this repo's `cores/<core>/` into your jtcores checkout (for `mechatt`, also `cores/bbusters/`: the shared
   video).
3. Build: `jtcore <core> -mister -c` (e.g. `jtcore gwar -mister -c`).

📋 **Step-by-step in [`BUILD.md`](BUILD.md).**

## ROMs

**Not included** (copyrighted material). Bring your own MAME romsets (**merged**, MAME 0.288: `gwar.zip`; `mechatt.zip` + `ym2608.zip`). The `.mra`
describes how to assemble it; every ROM is loaded at runtime.

## Credits

- **JTFRAME** and **jtopl** (Jose Tejada) — the GPLv3 framework and OPL module this core is built on
- **T80** (Daniel Wallner and contributors) — the Z80 CPU, as packaged in JTFRAME
- **MAME** — hardware reference: the `snk/snk.cpp` driver (Ernesto Corvi, Tim Lindquist, Carlos A. Lozano, Bryan
  McPhail, Jarek Parchanski, Nicola Salmoria, Tomasz Slanina, Phil Stroffolino, Acho A. Tang, Victor Trucco), the
  board documentation by **Guru**, and the **ymfm** sound library (Aaron Giles) as the behavioural reference for the
  Y8950
- **JT12 / JT49** (Jose Tejada) — the FM and SSG parts of the YM2608 in Mechanized Attack
- **fx68k** (Jorge Cwik) — the 68000 CPU, as packaged in JTFRAME
- **MAME** — for Mechanized Attack: the `snk/mechatt.cpp` driver and the `snk_bbusters_spr` sprite device (Bryan
  McPhail), and **ymfm** (Aaron Giles) as the behavioural reference for the YM2608

## Acknowledgements

- To **Sorgelig** and the whole **MiSTer FPGA** project and community.
- To the **MAME community**, for the preservation and reverse-engineering work without which this core would not be
  possible.
- And to **Anthropic**, for **Claude**.

## License

**GPLv3** (see [`LICENSE`](LICENSE)) — required by the JTFRAME / jtopl / JT12 dependencies; their copyright notices are
preserved in the sources.

---

## Español

🇪🇸 Español · [🇬🇧 English ↑](#snk-fpga)

Recreaciones en FPGA de placas arcade de **SNK**, construidas sobre el framework **JTFRAME** (GPLv3). Objetivo MiSTer.

> ℹ️ Proyecto independiente — **NO** es un core oficial de jotego. Construido sobre su framework JTFRAME (GPLv3).

## Cores

### Guerrilla War (SNK, 1987)
Run-and-gun vertical sobre el hardware "triple Z80" de SNK (placas A6003/A6004). Hardware: **tres Z80** a 4 MHz
(principal y secundaria comparten toda su RAM y se sincronizan con NMI cruzadas; la tercera lleva el sonido) +
**YM3526** (OPL) + **Y8950** (OPL + voces ADPCM) + los customs de vídeo de SNK **SNK8601 / SNK8602**, escritos de cero
para este core: un fondo de 512×512 con scroll y tiles de 16×16, una capa de texto de 8×8 y 96 sprites (64 de 16×16 y
32 de 32×32) en tres pasadas de prioridad. El color sale de tres PROM de 4 bits. El **canal ADPCM del Y8950**, que no
existe en ningún módulo FPGA previo, se escribió para este core y coincide con MAME muestra a muestra. 400×224
(vertical).

**Estado: jugable en MiSTer** — probado en placa (arranque, monedas, controles, efectos de sonido). En simulación, el
vídeo coincide píxel a píxel con MAME en 225 de 225 escenas de referencia (arranque, demo, partida y pantalla
volteada); la CPU de sonido sigue los comandos de MAME (el 99,6 % de las escrituras a los YM coinciden en orden a lo
largo de 2300 cuadros, y las voces salen en el mismo cuadro), y la salida ADPCM del Y8950 es igual a la de MAME en 3,3
millones de muestras.

**Joystick rotatorio:** el original usa un mando rotatorio de 12 posiciones. Los botones 3 y 4 giran la mira a
izquierda/derecha (manteniéndolos sigue girando). **Limitación conocida:** el timing de vídeo real de los SNK8601/8602
no está documentado; el core usa reloj de píxel de 8 MHz, 512×264 (15,625 kHz / 59,19 Hz), mientras que MAME usa 60 Hz
nominales.

Hay un `.rbf` precompilado en [`releases/`](releases/) — **distribuible**: todas las ROMs del juego se cargan en
**tiempo de ejecución** desde el `.mra`; el bitstream no lleva datos del juego. O compílalo desde las fuentes
(`cores/gwar/`). Ver [`BUILD.md`](BUILD.md).

### Mechanized Attack (SNK, 1989)
Juego de disparos con pistola para dos jugadores sobre la placa SNK A8002. Hardware: **68000** a 12 MHz + **Z80** a
4 MHz para el sonido + **YM2608** (OPNA: 6 canales FM, SSG, ritmo y voces ADPCM-B), dos fondos de 16×16 con scroll de
256×32 tiles, una capa de texto de 8×8 y un generador de sprites con zoom (sprites de 16 a 128 píxeles escalados por
una tabla en ROM). El vídeo es compartido con Beast Busters. No existía un YM2608 en FPGA: la **sección de ritmo y el
canal ADPCM-B** se escribieron para este core y coinciden con el ymfm de MAME muestra a muestra; las partes FM y SSG
reutilizan JT12. 256×224 (horizontal).

**Estado: jugable en MiSTer** — probado en placa (arranque, monedas, una partida completa, gráficos, música y efectos,
pistolas con una GunCon 3). En simulación, el vídeo coincide píxel a píxel con MAME en 149 de 149 escenas de
referencia (título, demo y una partida completa, ~30 000 cuadros), y la CPU de sonido sigue los comandos de MAME: las escrituras al YM2608 coinciden con MAME
a lo largo de 900 cuadros, salvo dos confirmaciones de flags de timer que llegan con un sondeo de diferencia.

**Pistolas:** dos pistolas mediante el soporte de pistola de MiSTer (ratón, Sinden, Gun4IR, GunCon o stick
analógico), con mira en pantalla. Calíbralas dentro del core (OSD → *Define joystick buttons* → F10). Gatillo = botón
1, granada = botón 2. **Limitaciones conocidas:** el timing de vídeo real de la placa no está documentado; el core usa
reloj de píxel de 6 MHz, 384×264 (15,6 kHz / 59,2 Hz), mientras que MAME usa 60 Hz nominales. Los solenoides de
retroceso de las pistolas no se manejan.

Hay un `.rbf` precompilado en [`releases/`](releases/) — **distribuible**: todas las ROMs del juego, incluida la ROM
interna de ritmo del YM2608 (`ym2608.zip`), se cargan en **tiempo de ejecución** desde el `.mra`. O compílalo desde
las fuentes (`cores/mechatt/`, más el vídeo compartido de `cores/bbusters/hdl/`). Ver [`BUILD.md`](BUILD.md).

## Compilar

Este repo contiene **solo el código del core** (`cores/<core>/`). El framework y los módulos de terceros (jtframe,
jtopl, jt12) **no se incluyen**. Versión rápida:

1. Clona [jtcores](https://github.com/jotego/jtcores) (trae jtframe + módulos).
2. Copia `cores/<core>/` de este repo en tu copia de jtcores (para `mechatt`, también `cores/bbusters/`: el vídeo
   compartido).
3. Compila: `jtcore <core> -mister -c` (p. ej. `jtcore gwar -mister -c`).

📋 **Paso a paso en [`BUILD.md`](BUILD.md).**

## ROMs

**No se incluyen** (material con copyright). Usa tus propios romsets de MAME (**merged**, MAME 0.288: `gwar.zip`; `mechatt.zip` + `ym2608.zip`). El
`.mra` describe cómo montarlo; todas las ROMs se cargan en tiempo de ejecución.

## Créditos

- **JTFRAME** y **jtopl** (Jose Tejada) — el framework y el módulo OPL GPLv3 sobre los que se construye este core
- **T80** (Daniel Wallner y colaboradores) — la CPU Z80, tal como la empaqueta JTFRAME
- **MAME** — referencia del hardware: el driver `snk/snk.cpp` (Ernesto Corvi, Tim Lindquist, Carlos A. Lozano, Bryan
  McPhail, Jarek Parchanski, Nicola Salmoria, Tomasz Slanina, Phil Stroffolino, Acho A. Tang, Victor Trucco), la
  documentación de la placa de **Guru** y la biblioteca de sonido **ymfm** (Aaron Giles) como referencia de
  comportamiento del Y8950
- **JT12 / JT49** (Jose Tejada) — las partes FM y SSG del YM2608 de Mechanized Attack
- **fx68k** (Jorge Cwik) — la CPU 68000, tal como la empaqueta JTFRAME
- **MAME** — para Mechanized Attack: el driver `snk/mechatt.cpp` y el dispositivo de sprites `snk_bbusters_spr` (Bryan
  McPhail), e **ymfm** (Aaron Giles) como referencia de comportamiento del YM2608

## Agradecimientos

- A **Sorgelig** y a todo el proyecto y la comunidad de **MiSTer FPGA**.
- A la **comunidad de MAME**, por el trabajo de preservación e ingeniería inversa sin el que este core no sería
  posible.
- Y a **Anthropic**, por **Claude**.

## Licencia

**GPLv3** (ver [`LICENSE`](LICENSE)) — la exigen las dependencias JTFRAME / jtopl / JT12; sus avisos de copyright se
conservan en las fuentes.

<!-- omf_release:dependencias:ffgwar -->
## Dependencias externas de `ffgwar`

Este repositorio contiene **solo el código de los cores**. Para compilar `ffgwar`
hacen falta estas piezas, que se distribuyen desde su propio origen:

| Qué | De dónde | Dónde va |
|---|---|---|
| jtframe — framework de compilacion y modulos comunes (SDRAM, descarga, CPU Z80 = T80 de Daniel Wallner, RAM) | [https://github.com/jotego/jtframe](https://github.com/jotego/jtframe) | `modules/jtframe` |
| jtopl — YM3526 (y la parte FM del Y8950) | [https://github.com/jotego/jtopl](https://github.com/jotego/jtopl) | `modules/jtopl` |
<!-- /omf_release:dependencias:ffgwar -->

<!-- omf_release:dependencias:ffmechatt -->
## Dependencias externas de `ffmechatt`

Este repositorio contiene **solo el código de los cores**. Para compilar `ffmechatt`
hacen falta estas piezas, que se distribuyen desde su propio origen:

| Qué | De dónde | Dónde va |
|---|---|---|
| bbusters — video compartido con Beast Busters (jtbbusters_video/tilelayer/obj.v): incluido en ESTE repo, en cores/bbusters/hdl | [https://github.com/jlrh/snk-fpga](https://github.com/jlrh/snk-fpga) | `cores/bbusters` |
| jtframe — framework de compilacion y modulos comunes (SDRAM, descarga, pistolas, CPU 68000 = fx68k de Jorge Cwik, CPU Z80 = T80 de Daniel Wallner, RAM) | [https://github.com/jotego/jtframe](https://github.com/jotego/jtframe) | `modules/jtframe` |
| jt12 — FM y SSG (jt49) del YM2608 | [https://github.com/jotego/jt12](https://github.com/jotego/jt12) | `modules/jt12` |
<!-- /omf_release:dependencias:ffmechatt -->

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

## Build

This repo contains **only the core code** (`cores/<core>/`). The framework and third-party modules (jtframe, jtopl)
are **not included**. Quick version:

1. Clone [jtcores](https://github.com/jotego/jtcores) (brings jtframe + modules).
2. Copy this repo's `cores/<core>/` into your jtcores checkout.
3. Build: `jtcore <core> -mister -c` (e.g. `jtcore gwar -mister -c`).

📋 **Step-by-step in [`BUILD.md`](BUILD.md).**

## ROMs

**Not included** (copyrighted material). Bring your own MAME romset (**merged**, MAME 0.288, `gwar.zip`). The `.mra`
describes how to assemble it; every ROM is loaded at runtime.

## Credits

- **JTFRAME** and **jtopl** (Jose Tejada) — the GPLv3 framework and OPL module this core is built on
- **T80** (Daniel Wallner and contributors) — the Z80 CPU, as packaged in JTFRAME
- **MAME** — hardware reference: the `snk/snk.cpp` driver (Ernesto Corvi, Tim Lindquist, Carlos A. Lozano, Bryan
  McPhail, Jarek Parchanski, Nicola Salmoria, Tomasz Slanina, Phil Stroffolino, Acho A. Tang, Victor Trucco), the
  board documentation by **Guru**, and the **ymfm** sound library (Aaron Giles) as the behavioural reference for the
  Y8950

## Acknowledgements

- To **Sorgelig** and the whole **MiSTer FPGA** project and community.
- To the **MAME community**, for the preservation and reverse-engineering work without which this core would not be
  possible.
- And to **Anthropic**, for **Claude**.

## License

**GPLv3** (see [`LICENSE`](LICENSE)) — required by the JTFRAME / jtopl dependencies; their copyright notices are
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

## Compilar

Este repo contiene **solo el código del core** (`cores/<core>/`). El framework y los módulos de terceros (jtframe,
jtopl) **no se incluyen**. Versión rápida:

1. Clona [jtcores](https://github.com/jotego/jtcores) (trae jtframe + módulos).
2. Copia `cores/<core>/` de este repo en tu copia de jtcores.
3. Compila: `jtcore <core> -mister -c` (p. ej. `jtcore gwar -mister -c`).

📋 **Paso a paso en [`BUILD.md`](BUILD.md).**

## ROMs

**No se incluyen** (material con copyright). Usa tu propio romset de MAME (**merged**, MAME 0.288, `gwar.zip`). El
`.mra` describe cómo montarlo; todas las ROMs se cargan en tiempo de ejecución.

## Créditos

- **JTFRAME** y **jtopl** (Jose Tejada) — el framework y el módulo OPL GPLv3 sobre los que se construye este core
- **T80** (Daniel Wallner y colaboradores) — la CPU Z80, tal como la empaqueta JTFRAME
- **MAME** — referencia del hardware: el driver `snk/snk.cpp` (Ernesto Corvi, Tim Lindquist, Carlos A. Lozano, Bryan
  McPhail, Jarek Parchanski, Nicola Salmoria, Tomasz Slanina, Phil Stroffolino, Acho A. Tang, Victor Trucco), la
  documentación de la placa de **Guru** y la biblioteca de sonido **ymfm** (Aaron Giles) como referencia de
  comportamiento del Y8950

## Agradecimientos

- A **Sorgelig** y a todo el proyecto y la comunidad de **MiSTer FPGA**.
- A la **comunidad de MAME**, por el trabajo de preservación e ingeniería inversa sin el que este core no sería
  posible.
- Y a **Anthropic**, por **Claude**.

## Licencia

**GPLv3** (ver [`LICENSE`](LICENSE)) — la exigen las dependencias JTFRAME / jtopl; sus avisos de copyright se
conservan en las fuentes.

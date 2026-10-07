# Building the cores (reproducible)

🇬🇧 English (below) · [🇪🇸 Español](#compilar-los-cores-reproducible)

Steps to rebuild any `.rbf` in this repo from scratch. **No patch is required**: every game ROM is loaded at
**runtime** from the `.mra`, so each bitstream is distributable as-is. Tested for MiSTer.

## Requirements (all cores)
- A [**jtcores**](https://github.com/jotego/jtcores) checkout (brings jtframe, jtopl and jt12 as modules) and its toolchain
  (`setprj.sh`, `jtcore`).
- **Quartus** (the version your MiSTer board needs).
- Your own ROMs for the game (not included) — see [`README.md`](README.md).

## Guerrilla War

1. **Place the core** inside jtcores:
   ```
   cp -r cores/gwar  <jtcores>/cores/gwar
   ```
2. **Build** (generate + compile):
   ```
   cd <jtcores> && source setprj.sh
   jtcore gwar -mister -c
   ```
   This generates `<jtcores>/cores/gwar/mister/` (Quartus project + the memgen GAMETOP `jtgwar_game_sdram.v`) and
   compiles it. The result is the `.rbf` under `mister/output_files/`.

**ROM layout.** The sprite ROMs (one file per bitplane) are packed four planes per 32-bit word by the `.mra` itself
(`<interleave output="32">`); the text tiles and the three colour PROMs go to BRAM. Use the `.mra` from
`cores/gwar/mra/`: it is the one the bitstream expects.


## Beast Busters

1. **Place the core** inside jtcores:
   ```
   cp -r cores/bbusters  <jtcores>/cores/bbusters
   ```
   `cores/bbusters/hdl/jt10_adpcmb_cnt.v` replaces the file of the same name in JT12 (ADPCM-B end-of-sample flag on
   reset); `cores/bbusters/cfg/files.yaml` already takes it from the core and the rest of the ADPCM files from JT12.
2. **Build:**
   ```
   cd <jtcores> && source setprj.sh
   jtcore bbusters -mister -c
   ```

**ROM layout.** The `.mra` loads `bbusters.zip`: the two sprite banks go to separate SDRAM banks, together with the
YM2610 ADPCM-A/B samples; the sprite scaling table goes to BRAM. The gun calibration EEPROM is saved as NVRAM. Use the
`.mra` from `cores/bbusters/mra/`.

## Mechanized Attack

1. **Place the core and the shared video** inside jtcores:
   ```
   cp -r cores/mechatt   <jtcores>/cores/mechatt
   cp -r cores/bbusters  <jtcores>/cores/bbusters
   ```
   `cores/bbusters/hdl/` holds the video modules shared with Beast Busters (`jtbbusters_video/tilelayer/obj.v`);
   `cores/mechatt/cfg/files.yaml` pulls them in.
2. **Build:**
   ```
   cd <jtcores> && source setprj.sh
   jtcore mechatt -mister -c
   ```

**ROM layout.** The `.mra` loads `mechatt.zip` and the YM2608 internal rhythm ROM from `ym2608.zip`
(`ym2608_adpcm_rom.bin`); the sprite scaling table goes to BRAM. Use the `.mra` from `cores/mechatt/mra/`.

---

# Compilar los cores (reproducible)

🇪🇸 Español · [🇬🇧 English ↑](#building-the-cores-reproducible)

Pasos para recompilar desde cero cualquier `.rbf` de este repo. **No hace falta ningún parche**: todas las ROMs del
juego se cargan en **tiempo de ejecución** desde el `.mra`, así que cada bitstream es distribuible tal cual. Probado
para MiSTer.

## Requisitos (todos los cores)
- Una copia de [**jtcores**](https://github.com/jotego/jtcores) (trae jtframe, jtopl y jt12 como módulos) y sus
  herramientas (`setprj.sh`, `jtcore`).
- **Quartus** (la versión que pida tu placa MiSTer).
- Tus propias ROMs del juego (no incluidas) — ver [`README.md`](README.md).

## Guerrilla War

1. **Coloca el core** dentro de jtcores:
   ```
   cp -r cores/gwar  <jtcores>/cores/gwar
   ```
2. **Compila** (genera + compila):
   ```
   cd <jtcores> && source setprj.sh
   jtcore gwar -mister -c
   ```
   Esto genera `<jtcores>/cores/gwar/mister/` (proyecto de Quartus + el GAMETOP de memgen `jtgwar_game_sdram.v`) y
   lo compila. El `.rbf` queda en `mister/output_files/`.

**Organización de las ROMs.** Las ROMs de sprites (un fichero por plano) las empaqueta la propia `.mra` en palabras de
32 bits con cuatro planos (`<interleave output="32">`); los tiles de texto y las tres PROM de color van a BRAM. Usa la
`.mra` de `cores/gwar/mra/`: es la que espera el bitstream.

## Beast Busters

1. **Coloca el core** dentro de jtcores:
   ```
   cp -r cores/bbusters  <jtcores>/cores/bbusters
   ```
   `cores/bbusters/hdl/jt10_adpcmb_cnt.v` sustituye al fichero del mismo nombre de JT12 (flag de fin de muestra del
   ADPCM-B en el reinicio); `cores/bbusters/cfg/files.yaml` ya lo toma del core y el resto del ADPCM de JT12.
2. **Compila:**
   ```
   cd <jtcores> && source setprj.sh
   jtcore bbusters -mister -c
   ```

**Reparto de las ROMs.** El `.mra` carga `bbusters.zip`: los dos bancos de sprites van a bancos de SDRAM distintos,
junto con las muestras ADPCM-A/B del YM2610; la tabla de escalado de sprites va a BRAM. La EEPROM con la calibración de
las pistolas se guarda como NVRAM. Usa el `.mra` de `cores/bbusters/mra/`.

## Mechanized Attack

1. **Coloca el core y el vídeo compartido** dentro de jtcores:
   ```
   cp -r cores/mechatt   <jtcores>/cores/mechatt
   cp -r cores/bbusters  <jtcores>/cores/bbusters
   ```
   `cores/bbusters/hdl/` contiene los módulos de vídeo compartidos con Beast Busters
   (`jtbbusters_video/tilelayer/obj.v`); `cores/mechatt/cfg/files.yaml` los incluye.
2. **Compila:**
   ```
   cd <jtcores> && source setprj.sh
   jtcore mechatt -mister -c
   ```

**Reparto de las ROMs.** El `.mra` carga `mechatt.zip` y la ROM interna de ritmo del YM2608 de `ym2608.zip`
(`ym2608_adpcm_rom.bin`); la tabla de escalado de sprites va a BRAM. Usa el `.mra` de `cores/mechatt/mra/`.

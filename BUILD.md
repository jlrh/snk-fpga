# Building the cores (reproducible)

🇬🇧 English (below) · [🇪🇸 Español](#compilar-los-cores-reproducible)

Steps to rebuild any `.rbf` in this repo from scratch. **No patch is required**: every game ROM is loaded at
**runtime** from the `.mra`, so each bitstream is distributable as-is. Tested for MiSTer.

## Requirements (all cores)
- A [**jtcores**](https://github.com/jotego/jtcores) checkout (brings jtframe + jtopl as modules) and its toolchain
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

---

# Compilar los cores (reproducible)

🇪🇸 Español · [🇬🇧 English ↑](#building-the-cores-reproducible)

Pasos para recompilar desde cero cualquier `.rbf` de este repo. **No hace falta ningún parche**: todas las ROMs del
juego se cargan en **tiempo de ejecución** desde el `.mra`, así que cada bitstream es distribuible tal cual. Probado
para MiSTer.

## Requisitos (todos los cores)
- Una copia de [**jtcores**](https://github.com/jotego/jtcores) (trae jtframe + jtopl como módulos) y sus
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

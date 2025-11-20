# Blinkenlights Decoder + 8×8 LED Matrix (Cadence + Verilog on DE0-CV)

This project combines a custom CMOS decoder + ROM with an FPGA-based 8×8 LED matrix driver.  
At the transistor level, it implements a 3→8 active-high decoder and a 7-bit ROM that stores the ASCII characters **H-E-L-L-O**. At the RTL level, it drives an external 8×8 common-cathode LED matrix from a **DE0-CV (Cyclone V 5CEBA4F23C7)** board, scanning rows and reading pixel data from a ROM-based frame buffer. :contentReference[oaicite:0]{index=0}  

The design has been synthesized, loaded, and **verified on real hardware**: the word **“HELLO”** animates across the matrix at a visible frame rate with stable brightness and no flicker. :contentReference[oaicite:1]{index=1}  

---

## Features

- **Custom CMOS decoder hierarchy**
  - 1→2 active-high decoder cell implemented with static CMOS logic.
  - Hierarchical composition to build a 3→8 active-high decoder with enable. :contentReference[oaicite:2]{index=2}  

- **ROM storing ASCII “HELLO”**
  - 7-bit word slices using CMOS transmission gates to connect constant 0/1 bits onto a shared bus.
  - Stores 7-bit ASCII characters: H, E, L, L, O (bit6..bit0). :contentReference[oaicite:3]{index=3}  

- **Transistor-level simulation**
  - Uses `vbit` sources to cycle through address lines and enable, generating the sequence H → E → L → L → O on the ROM bus. :contentReference[oaicite:4]{index=4}  

- **FPGA LED-matrix driver (Verilog)**
  - Top-level `led_matrix` module for DE0-CV.
  - ROM `hello_rom_8x8` contains **5 frames** (H, E, L, L, O). :contentReference[oaicite:5]{index=5}  
  - Row scanner refreshes rows at ≈1.95 kHz for flicker-free images.
  - Frame counter advances at ≈0.5 Hz (2 seconds per frame) by default, easily tunable. :contentReference[oaicite:6]{index=6}  

- **Display orientation controls**
  - `MIRROR_COLS` to correct left/right mirroring.
  - `FLIP_ROWS` to correct upside-down images. :contentReference[oaicite:7]{index=7}  

- **Hardware-tested pinout for DE0-CV + 8×8 matrix**
  - Rows active-LOW, columns active-HIGH, matching the external matrix wiring. :contentReference[oaicite:8]{index=8}  

---

## Repository Structure (suggested)

You can organize the repository as follows:

```text
.
├── cadence/
│   ├── decoder_1to2/           # 1→2 decoder schematic/symbol/layout
│   ├── decoder_3to8/           # Hierarchical 3→8 decoder
│   ├── rom_7xN_hello/          # 7-bit ROM word slices for "HELLO"
│   └── testbench/              # vbit-driven testbench + stimuli
│
├── rtl/
│   ├── led_matrix.v            # Top-level DE0-CV LED matrix driver
│   ├── hello_rom_8x8.v         # 8x8 glyph ROM for letters
│   └── clockDivider.v          # 50 MHz → multiple derived clocks :contentReference[oaicite:9]{index=9}
│
├── constraints/
│   ├── de0cv_ledmatrix.sdc     # create_clock, timing constraints
│   └── de0cv_pins.qsf          # Pin assignments for DE0-CV + LED matrix
│
└── docs/
    ├── schematics/             # Decoder & ROM schematics screenshots
    ├── waveforms/              # Simulation waveforms (decoder / ROM)
    └── photos/                 # Board + LED matrix photos / demo GIFs
````

Feel free to rename folders, but keeping Cadence artifacts separate from RTL/FPGA files makes the flow easy to understand.

---

## Conceptual Design

### 1. Hierarchical Decoder

* Start from a **1→2 active-high decoder** with inputs `A` and enable `E` and outputs `D0`, `D1`:

  * `D0 = E · ¬A`
  * `D1 = E · A` 
* Build a **3→8 decoder** using multiple 1→2 blocks:

  * A2 is decoded first, generating enables for the upper and lower halves.
  * A1 is decoded within each half.
  * A0 is decoded for each of the 4 quarters, yielding eight one-hot outputs D0..D7. 

This structure highlights re-use and modular design: a single well-verified 1→2 block is instantiated multiple times to build larger decoders.

### 2. ROM Word Slices (“HELLO”)

* The ROM is **7×N** (7 bits per word, N ≥ 5 words). Each word corresponds to one ASCII character:

  * `H = 1001000`
  * `E = 1000101`
  * `L = 1001100`
  * `O = 1001111` 
* Each word line uses:

  * Constant nets tied to VDD or VSS for each bit.
  * A transmission gate (or tri-state device) per bit, enabled by the word’s select `SEL` and its complement `~SEL`, to connect the word onto the bus. 

When the decoder asserts `Dk`, only word `k` drives the 7-bit bus; all other words are effectively high-impedance, so the bus behaves like a simple ROM output.

### 3. Transistor-Level Testbench

To verify the decoder + ROM:

* Use `analogLib/vbit` sources for `A0`, `A1`, `A2`, and `E`. Typical bit periods: 

  * `A0`: period 40 µs (fastest)
  * `A1`: period 80 µs
  * `A2`: period 160 µs
  * `E`: constant logic high (either via `vbit` or `vdc`)
* Run a transient simulation to 800 µs with a suitable max step.
* Expected bus sequence (bit6..bit0):

  * `000` → H
  * `001` → E
  * `010` → L
  * `011` → L
  * `100` → O
  * `101`, `110`, `111` → high-Z / unused words

---

## FPGA LED Matrix Driver

### 1. Hardware Setup (DE0-CV + LED Matrix)

* **Board:** Terasic DE0-CV (Cyclone V, 5CEBA4F23C7). 
* **Display:** 8×8 common-cathode LED matrix connected to GPIO1.
* **Polarity:**

  * Rows: **active-LOW** (connect to cathodes).
  * Columns: **active-HIGH** (connect to anodes). 

Recommended pin mapping (rows 1–8, columns 1–8): 

| Row Index | FPGA Pin |
| --------: | -------- |
|    row[0] | PIN_R22  |
|    row[1] | PIN_T22  |
|    row[2] | PIN_N19  |
|    row[3] | PIN_P19  |
|    row[4] | PIN_P17  |
|    row[5] | PIN_M18  |
|    row[6] | PIN_L17  |
|    row[7] | PIN_K17  |

| Column Index | FPGA Pin |
| -----------: | -------- |
|       col[0] | PIN_N21  |
|       col[1] | PIN_R21  |
|       col[2] | PIN_N20  |
|       col[3] | PIN_M22  |
|       col[4] | PIN_L22  |
|       col[5] | PIN_P16  |
|       col[6] | PIN_L18  |
|       col[7] | PIN_L19  |

### 2. Top-Level Interface

The `led_matrix` module exposes:

```verilog
module led_matrix (
    input  wire        clk50,    // 50 MHz reference clock
    input  wire        reset_n,  // active-LOW reset (KEY0)
    input  wire        run,      // run/pause (e.g., SW0)
    output reg  [7:0]  row_n,    // active-LOW row selects
    output reg  [7:0]  col       // active-HIGH column selects
);
```

Internally:

* A `clockDivider` derives:

  * `Clock12_5Mhz` (for generic fast logic).
  * `Clock500Khz` (for row scanning).
  * `Clock0_5hz` (for frame stepping). 
* An 8-bit counter driven by `Clock500Khz` selects which row is active; each row is refreshed often enough to exploit persistence of vision.
* A frame counter uses edges of `Clock0_5hz` to step through H → E → L → L → O. 
* The ROM `hello_rom_8x8` returns a column bitmap for the current `(frame_idx, row_idx)`.

### 3. LED Matrix Scanning

Because the matrix is common-cathode:

1. Compute a one-hot row mask: `row_onehot = 8'b0000_0001 << row_idx`.
2. Invert it to obtain active-LOW row select: `row_n = ~row_onehot`.
3. On each row period:

   * Read the columns for `(current_frame, row_idx)` from `hello_rom_8x8`.
   * Optionally mirror or flip them with `MIRROR_COLS` / `FLIP_ROWS`.
   * Drive `col` with the active-HIGH pattern.

This approach ensures only one row is active at any time, and the human eye integrates the fast row updates into a stable image. 

---

## Building & Running on DE0-CV

### Prerequisites

* **Tools**

  * Intel Quartus Prime (for synthesis, P&R, and programming).
  * Optional: ModelSim (for RTL simulation).
* **Hardware**

  * DE0-CV board (Cyclone V).
  * 8×8 common-cathode LED matrix wired to GPIO1 as above.
  * USB-Blaster cable.

### Steps

1. **Create a new Quartus project**

   * Target device: Cyclone V 5CEBA4F23C7.
   * Add `rtl/led_matrix.v`, `rtl/hello_rom_8x8.v`, `rtl/clockDivider.v`.

2. **Set timing constraints**

   * Add an SDC file with the main clock constraint:

     ```tcl
     create_clock -name clk50 -period 20.000 [get_ports clk50]
     ```

     (50 MHz → 20 ns period). 

3. **Assign pins**

   * Map `clk50`, `reset_n`, and `run` to the appropriate DE0-CV pins (e.g., `CLOCK_50`, `KEY0`, `SW0`).
   * Map `row_n[7:0]` and `col[7:0]` using the pinout tables above.

4. **Compile**

   * Run Analysis & Synthesis, then Fitter.
   * Check that timing is met (no failing setup/hold paths).

5. **Program the board**

   * Use the Quartus Programmer with the USB-Blaster.
   * Power up the board, program the `.sof` file.

6. **Demo**

   * Set `run` high and release `reset_n`.
   * The letters H → E → L → L → O should appear one by one on the 8×8 matrix at about **0.5 Hz**.
   * Row scanning should be flicker-free thanks to the ~1.95 kHz row refresh. 

---

## Working With Cadence (Decoder + ROM)

If you keep the transistor-level design in this repository, a typical flow is:

1. **Open the decoder and ROM cells**

   * Verify the 1→2 decoder logic and symbol pins (A, E, D0, D1).
   * Inspect the 3→8 schematic to ensure enables and outputs match the truth table. 

2. **Check the ROM word slices**

   * Confirm each ASCII bit is tied to the correct constant for H/E/L/L/O.
   * Ensure each slice uses both `SEL` and `~SEL` to drive a transmission gate, so 0 and 1 are driven strongly. 

3. **Run the testbench**

   * Apply the `vbit` stimuli for A0/A1/A2/E as described earlier.
   * Observe the 7-bit bus transitioning through the expected character codes.

4. **Debugging hints**

   * If you see small, noisy voltages on decoder outputs, check for:

     * Missing power/ground connections.
     * Pass-only networks instead of proper CMOS gates.
     * Floating nodes or missing enables. 

---

## Troubleshooting

Some common issues and fixes:

* **All LEDs are on or scrambled**

  * Verify row polarity (active-LOW) and column polarity (active-HIGH).
  * Confirm pin assignments match the matrix wiring.
  * Try a “walking dot” pattern: drive only one row and one column at a time to debug wiring. 

* **Image is mirrored or upside-down**

  * Toggle the `MIRROR_COLS` parameter to correct left/right mirroring.
  * Toggle `FLIP_ROWS` if the text appears upside-down. 

* **Flicker**

  * Ensure row scanning clock (`Clock500Khz`) and row counter logic are correct.
  * A row refresh rate of ≥1 kHz is recommended to avoid visible flicker. 

* **No frame changes**

  * Check that `Clock0_5hz` is toggling.
  * Verify the edge detection that generates a `frame_tick`.
  * Confirm that `run` is asserted (high) so the frame counter advances.

---

## Extending the Project

Here are a few ideas to build on this project:

* **Custom messages or icons**

  * Modify `hello_rom_8x8` to add more frames (e.g., scrolling text, emojis, or patterns).

* **Variable speed control**

  * Add a switch or buttons to adjust frame rate or row refresh.

* **Multiple words / animations**

  * Extend the ROM depth and frame counter to display different words, or loop through multiple animations.

* **Higher-level interfaces**

  * Add a UART, SPI, or AXI-Lite interface so an external processor can stream patterns into the ROM or a RAM buffer.


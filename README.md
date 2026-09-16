# Autotune in RTL: A Cycle-Accurate Phase-Vocoder Pitch-Shifting Datapath

A DSP course project (EE-317, IIT Indore) implementing real-time audio pitch correction
("autotune") using a **phase vocoder** architecture — analyzed and prototyped in Python,
then implemented as a cycle-accurate, pipelined **Verilog RTL** datapath on FPGA.

Pitch shifting is performed in the frequency domain rather than by simple time-domain
resampling, so that pitch can be corrected **without changing the tempo** of the audio.

## Pipeline overview

```
Ingestion → Windowing (Hanning) → FFT → Rect→Polar (CORDIC) → Pitch Detection
  → Tuning ROM lookup → Magnitude Resampling → Phase Unwrapping
  → Polar→Rect (CORDIC) → IFFT → Overlap-Add → Export
```

The **RTL core** (this repo's primary deliverable) implements Steps 3–10 of the pipeline:
FFT → magnitude/phase conversion → pitch detection → tuning-ratio lookup → magnitude
resampling → phase unwrapping → reconstruction → IFFT, for a single N-sample frame.
Windowing (frame extraction + Hanning window) and the final Overlap-Add reconstruction
are handled in the Python software layer.

See [`PS.pdf`](PS.pdf) for the full project specification and [`Mid-Eval/`](Mid-Eval) for
the detailed written report.

## Repository structure

```
├── AutotuneRTLProject.ipynb   Python golden model: STFT, CORDIC/FFT test-vector
│                              generation, tuning ROM table, sine/composite test signals
├── PS.pdf                     Project specification
├── sample-speech-1m.wav       Sample input audio used for testing
├── Mid-Eval/                  Mid-evaluation report (LaTeX source + PDF)
└── RTL Part/                  Vivado project — Verilog RTL implementation
    ├── RTL Part.srcs/         Verilog sources, testbenches, and IP core configs (.xci)
    │   ├── sources_1/new/     fft.v, ifft.v, conversion.v, reconstruction.v,
    │   │                      overlap-add.v, ifft_ola.v, output_handler.v, ...
    │   └── sim_1/new/         Testbenches
    ├── RTL Part.xpr           Vivado project file
    └── *.mem                  Simulation memory-init files (audio frames, tuning ROM,
                                sine/harmonic test vectors)
```

> **Note:** Vivado-generated build products (`*.cache`, `*.gen`, `*.hw`, `*.ip_user_files`,
> `*.runs`, `*.sim`, `.Xil/`, logs/journals) are excluded via `.gitignore` since they are
> regenerated automatically when the project is opened in Vivado.

## Key hardware blocks

| Block | File(s) | Function |
|---|---|---|
| FFT / IFFT | `fft.v`, `ifft.v` | Spectral transform via Xilinx `xfft` IP core |
| Rect ↔ Polar conversion | `conversion.v`, `cordic_converter.v` | CORDIC-based magnitude/phase extraction and reconstruction |
| Pitch analysis | `analysis.v`, `transformation.v` | Fundamental-frequency detection and tuning-ratio calculation |
| Reconstruction | `reconstruction.v` | Modified magnitude/phase → complex spectrum |
| Overlap-Add | `overlap-add.v`, `overlapadd.v`, `ifft_ola.v` | Frame reconstruction |
| Output handling | `output_handler.v`, `mem_reader.v` | Sample I/O to/from memory |

## Getting started

**Python golden model**
```bash
jupyter notebook AutotuneRTLProject.ipynb
```

**RTL simulation (Vivado)**
1. Open `RTL Part/RTL Part.xpr` in Xilinx Vivado.
2. Let Vivado regenerate IP output products (`Generate Output Products` in the IP flow).
3. Run behavioral simulation on the desired testbench under `sim_1/new/`.

## Team

Rohan Jain, Dhananjay Dhumal, Gadgil Rucha Vinay, Karan Hitesh Bagthariya

## References

1. J. L. Flanagan and R. M. Golden, "Phase vocoder," *Bell System Technical Journal*, vol. 45, no. 9, pp. 1493–1509, Nov. 1966.
2. M. R. Portnoff, "Implementation of the digital phase vocoder using the fast Fourier transform," *IEEE Trans. Acoust., Speech, Signal Process.*, vol. 24, no. 3, pp. 243–248, Jun. 1976.
3. J. Laroche and M. Dolson, "Improved phase vocoder time-scale modification of audio," *IEEE Trans. Speech Audio Process.*, vol. 7, no. 3, pp. 323–332, May 1999.
4. J. E. Volder, "The CORDIC trigonometric computing technique," *IRE Trans. Electron. Comput.*, vol. EC-8, no. 3, pp. 330–334, Sep. 1959.
5. J. W. Cooley and J. W. Tukey, "An algorithm for the machine calculation of complex Fourier series," *Math. Comput.*, vol. 19, no. 90, pp. 297–301, 1965.

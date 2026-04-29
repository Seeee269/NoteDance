# CMLS Project — Sensor-Driven Sound Toy

An RC-car / handheld board controls a sound source through a 3-axis
accelerometer. SuperCollider produces a stable musical source (continuous
drone or looped melody); a JUCE plugin receives that audio and reshapes it
(pitch / playback speed / panning) according to live sensor data.

## Architecture

```
[Accelerometer] --serial--> [Python bridge] --OSC (dual)--> [SuperCollider]
   (MPU6050)                                                 generates audio
                                                                   |
                                                                 audio
                                                                   v
                                                        [Virtual audio device]
                                                            (BlackHole 2ch)
                                                                   |
                                                                   v
                                                          [JUCE plugin host]
                                                          processes audio
                                                          using sensor OSC
```

## Repository layout

```
cmls/
├── supercollider/         SC source: musical source + OSC stub
│   └── cmls_proj.scd
├── juce/                  JUCE plugin project (TBD)
├── bridge/                Sensor → OSC bridge
│   ├── arduino_accel/     Arduino sketch (MPU6050 → serial CSV)
│   ├── bridge.py          Python serial → OSC dual-sender
│   └── requirements.txt
├── docs/                  Diagrams, report, demo media
├── .gitignore
└── README.md
```

## OSC protocol (single source of truth)

The Python bridge sends every message to **both** SuperCollider and the
JUCE plugin. Both receivers must agree on these names and types.

| Address          | Args                       | Notes                                     |
|------------------|----------------------------|-------------------------------------------|
| `/sensor/accel`  | `x y z`     (float, -1..1) | Normalised against `ACCEL_RANGE_G`        |
| `/sensor/tilt`   | `roll pitch` (float, rad)  | Derived from gravity assumption           |
| `/sensor/shake`  | `magnitude` (float, 0..~)  | IIR-smoothed inter-sample delta           |

Default ports: SC `57120`, JUCE `9001`. Override with bridge CLI flags.

## Module responsibilities

| Module        | Owns                                  | Does NOT own                          |
|---------------|---------------------------------------|---------------------------------------|
| Hardware      | Sensor wiring, Arduino sketch         | Any host-side processing              |
| Bridge        | Serial parsing, normalisation, OSC    | Audio, sound design                   |
| SuperCollider | Musical source, mix, master out       | Sensor-driven modulation              |
| JUCE          | Pitch / speed / pan / FX from sensors | Generating the source itself          |

If you find yourself crossing these lines, raise it in the team chat
before merging.

## Setup

### 1. SuperCollider

1. Install SuperCollider 3.13+.
2. Install [BlackHole 2ch](https://existential.audio/blackhole/) and set
   the macOS system output to it (or set SC's output device explicitly).
3. Open `supercollider/cmls_proj.scd`, evaluate blocks top-to-bottom,
   then `~start.value;`.

### 2. Bridge

```bash
cd bridge
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# real hardware
python3 bridge.py --port /dev/tty.usbmodem1101 --debug

# no hardware — emit a slow sine for SC/JUCE testing
python3 bridge.py --mock --debug
```

### 3. Arduino

1. Arduino IDE → Library Manager → install `Adafruit MPU6050` and
   `Adafruit Unified Sensor`.
2. Wire MPU6050: `VCC→3.3V, GND→GND, SCL→A5, SDA→A4` (Uno / Nano).
3. Open `bridge/arduino_accel/arduino_accel.ino`, upload, confirm the
   serial monitor at 115200 baud shows `x,y,z` lines in g units.

If the team uses a different sensor, only the Arduino sketch needs
changing — keep the serial format `x,y,z\n` (g units) intact.

### 4. JUCE

TBD. Place the JUCE project under `juce/`. The plugin must:

- expose stereo audio in / out;
- listen for OSC on `127.0.0.1:9001` using the addresses above;
- map sensor values to plugin parameters (suggested initial mapping:
  `accel.x` → playback speed, `tilt.roll` → stereo pan).

## Audio routing (macOS)

1. SC output device  → BlackHole 2ch.
2. JUCE plugin host input → BlackHole 2ch.
3. JUCE plugin host output → your speakers / headphones.

For monitoring while SC plays straight to BlackHole, create an
*Aggregate Device* or *Multi-Output Device* in Audio MIDI Setup.

## Workflow

- Default branch: `main` — always working, demo-ready.
- Feature branches per task: `feat/<area>-<short-name>`, e.g.
  `feat/juce-pitch`, `feat/sc-melody`, `feat/bridge-shake`.
- Open a PR for review before merging into `main`. At least one other
  team member must approve.
- Keep commits focused: one concern per commit, present-tense subject
  line, body explains *why* if non-obvious.
- Touching the OSC protocol table above requires coordination across SC
  and JUCE owners — don't merge unilaterally.

## Team

Six-person team across hardware, bridge, SuperCollider, JUCE, and
documentation. Update this section with names + areas of ownership when
the split is finalised.

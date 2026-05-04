# CMLS Project - Sensor-Driven Sound Prototype

Current focus: **SuperCollider standalone prototype**.

The project explores using an RC car or handheld board with a 3-axis
accelerometer to control sound. At this stage, SuperCollider can generate
either a continuous drone or a simple looping melody, and it can also respond
directly to sensor OSC data.

Future direction: the same SuperCollider source can later be routed into a
JUCE plugin if the team chooses to move sensor-driven processing into the
plugin.

## What Works Today

- A single SuperCollider script (`supercollider/cmls_proj.scd`) acts as a
  self-contained sensor-to-sound console.
- Two sound sources: a slowly evolving stereo drone and an 8-note pentatonic
  loop.
- Two control modes selectable from the top of the script:
  - `\standaloneSC` (default): incoming OSC immediately changes pitch, pan,
    filter brightness, and (for melody) tempo.
  - `\pluginSource`: SC ignores sensor motion and stays a stable source so a
    future JUCE plugin can take over the modulation.
- A Python bridge (`bridge/bridge.py`) that emits the same OSC protocol from
  either real Arduino/MPU6050 input or a `--mock` sine wave for testing
  without hardware.

## Current Architecture

### Current SC-first demo

```text
[Accelerometer / mock data]
          |
          v
[Python bridge, optional] --OSC--> [SuperCollider]
                                  generates and controls sound
                                           |
                                           v
                                    speakers/headphones
```

### Future JUCE option

```text
[SuperCollider] --> [Virtual audio device] --> [JUCE plugin host]
   source audio                              sensor-controlled processing
```

The current deliverable does not require JUCE. The `juce/` folder is a
placeholder for later team work.

## Repository Layout

```text
cmls/
|-- supercollider/         Current focus: SC sound + sensor OSC control
|   `-- cmls_proj.scd
|-- bridge/                Optional draft bridge: Arduino serial -> OSC
|   |-- arduino_accel/     Arduino sketch placeholder/draft for MPU6050
|   |-- bridge.py          Python serial/mock -> OSC sender
|   `-- requirements.txt
|-- juce/                  Placeholder for future JUCE plugin project
|-- docs/                  Placeholder for diagrams, report, demo media
|-- .gitignore
`-- README.md
```

## SuperCollider Modes

Open `supercollider/cmls_proj.scd` and choose these variables near the top:

```supercollider
~soundMode = \drone;          // \drone or \melody
~controlMode = \standaloneSC; // \standaloneSC or \pluginSource
```

- `\standaloneSC`: SuperCollider receives sensor OSC and directly changes the
  sound. This is the main mode for the current prototype.
- `\pluginSource`: SuperCollider ignores sensor motion and stays a stable
  drone/melody source for a future JUCE plugin.
- `\drone`: continuous sound, good for hearing pitch and filter movement.
- `\melody`: simple repeated pattern, good for hearing tempo/transposition.

## Sensor Mapping

In `\standaloneSC` mode:

| Sensor data      | Drone mode effect            | Melody mode effect                       |
|------------------|------------------------------|------------------------------------------|
| board pitch/tilt | continuous pitch bend        | per-note transposition + tempo (BPM)     |
| board roll       | stereo pan                   | stereo pan                               |
| shake magnitude  | filter brightness, loudness  | filter brightness, per-note loudness     |
| accel magnitude  | adds to brightness "energy"  | adds to brightness "energy"              |

Raw "up/down acceleration" is treated as board pitch/tilt because raw
accelerometer values are noisy for stable musical pitch control. If the board
feels inverted, change `tiltPitchPolarity` or `rollPanPolarity` in
`cmls_proj.scd` from `1` to `-1`.

## OSC Protocol

The current SC script listens on SuperCollider's default language port,
normally `57120`.

| Address          | Args                       | Notes                              |
|------------------|----------------------------|------------------------------------|
| `/sensor/accel`  | `x y z` floats, `-1..1`    | normalized acceleration axes       |
| `/sensor/tilt`   | `roll pitch` floats, rad   | used for pan, pitch, and tempo     |
| `/sensor/shake`  | `magnitude` float          | used for brightness and intensity  |

Debug controls:

| Address                | Args         | Notes                |
|------------------------|--------------|----------------------|
| `/control/master/amp`  | `amp` float  | master volume        |
| `/control/root/midi`   | `midi` float | root pitch in MIDI   |

## Running SuperCollider

1. Install SuperCollider 3.13+.
2. Open `supercollider/cmls_proj.scd`.
3. Evaluate the server config block, run `s.boot`, and wait until the server
   says it is ready.
4. Evaluate the remaining blocks from top to bottom.
5. Run:

```supercollider
~start.value;
```

Stop playback with:

```supercollider
~stop.value;
```

### 30-Second Demo Path

In one terminal, run the bridge in mock mode (no hardware needed):

```bash
cd bridge && python3 bridge.py --mock --debug
```

In SuperCollider, evaluate blocks 0 through 5 then `~start.value;`. With the
default `\standaloneSC` + `\drone` settings, you should immediately hear the
drone bend up and down and pan from side to side as the mock sine waves come
in over OSC.

Try the melody mode:

```supercollider
~soundMode = \melody;
~controlMode = \standaloneSC;
~start.value;
```

Try the future plugin-source behavior:

```supercollider
~soundMode = \drone;
~controlMode = \pluginSource;
~start.value;
```

## Optional Bridge Test

The bridge is not the main focus right now, but it can send mock sensor OSC
for SC testing.

```bash
cd bridge
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python3 bridge.py --mock --debug
```

For real hardware later:

```bash
python3 bridge.py --port /dev/tty.usbmodem1101 --debug
```

The Arduino sketch currently assumes an MPU6050 and prints `x,y,z` acceleration
values in g units. If the team uses another sensor, keep the same serial format
so the Python bridge does not need to change.

## Future JUCE Work

`juce/` is intentionally only a placeholder for now. If the team chooses the
JUCE route later, the plugin should:

- expose stereo audio input/output;
- receive OSC sensor messages, likely on `127.0.0.1:9001`;
- process SC audio with pitch, speed, pan, or effects driven by the sensor.

For that setup, route SuperCollider audio into a virtual audio device such as
BlackHole 2ch, then use that virtual device as the JUCE plugin host input.

## Team Workflow

- Keep `main` demo-ready.
- Use small feature branches such as `feat/sc-sensor-control`.
- Coordinate before changing the OSC address names or argument types.

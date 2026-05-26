# NoteDance - Sensor-Driven Sound Prototype

NoteDance is a sensor-controlled audio prototype that combines:

- **SuperCollider** for the main car/gesture soundscape.
- **Python OSC bridge** for real or mock accelerometer data.
- **JUCE plugin** for pitch-shifting and panning controlled by OSC.

The repository includes both the SuperCollider prototype and a working JUCE plugin project in `juce/`.

## Repository Layout

```text
NoteDance-main/
|-- supercollider/        SuperCollider sound prototype
|-- bridge/               Python sensor / OSC bridge and JUCE OSC tester
|-- juce/                 NoteDance JUCE plugin project
|-- docs/                 Notes, diagrams, report/demo material
|-- .gitignore
`-- README.md
```

## What Works

- `supercollider/cmls_proj.scd` runs the main SuperCollider sound prototype.
- `bridge/bridge.py` can use either real Arduino accelerometer data or mock sensor data.
- The Python bridge sends OSC data to SuperCollider and the JUCE port.
- `juce/` contains the **NoteDance** JUCE plugin with:
  - stereo input/output
  - input and output gain
  - pitch shifting
  - panning
  - OSC-controlled parameter updates
  - custom UI with rotary controls
  - Standalone and VST3 build targets

## Architecture

```text
[Accelerometer / mock data]
          |
          v
[Python bridge] --OSC--> [SuperCollider sound prototype]
          |
          '--OSC--> [JUCE plugin: pitch + pan processing]
```

SuperCollider currently creates the main audio scene. The JUCE plugin is designed as a downstream effect that can react to sensor movement through OSC.

# Hardware

The hardware setup is based on an RC car with an Arduino UNO WiFi Rev2 mounted on top. The system is powered by a 4xAA battery pack and includes a Grove rotary angle sensor.

The Arduino firmware connects to Wi-Fi automatically, allowing the hardware to operate entirely without using cables. It streams data from both the onboard accelerometer and the external rotary sensor, which is mechanically linked to the steering via a wire arm.

Communication uses OSC: messages are sent to the JUCE plugin on port `9001` and to SuperCollider on port `57120`, using the `/rotary` and `/accel` name tags.

## Running the SuperCollider Prototype

1. Install SuperCollider 3.13+.
2. Open `supercollider/cmls_proj.scd`.
3. Boot the server:

```supercollider
s.boot;
```

4. Evaluate the setup blocks from top to bottom.
5. Start playback:

```supercollider
~start.value;
```

Stop playback with:

```supercollider
~stop.value;
```

## Running the Python Bridge

Install dependencies:

```bash
cd bridge
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

Run with mock sensor data:

```bash
python3 bridge.py --mock --debug
```

Run with Arduino hardware:

```bash
python3 bridge.py --port /dev/tty.usbmodem1101 --debug
```

Default OSC destinations:

| Destination | Host | Port |
|-------------|------|------|
| SuperCollider | `127.0.0.1` | `57120` |
| JUCE | `127.0.0.1` | `9001` |

## JUCE Plugin

The JUCE implementation is in:

```text
juce/NoteDance.jucer
juce/Source/
juce/Assets/
juce/Builds/
```

Main source files:

| File | Purpose |
|------|---------|
| `PluginProcessor.cpp/.h` | audio processing and parameters |
| `PluginEditor.cpp/.h` | custom plugin interface |
| `Parameters.h` | input, output, pitch, mix, and pan parameters |
| `OSCReceiverComponent.h` | OSC control on UDP port `9001` |
| `MyPitchShifter.h` | custom pitch shifter |
| `MyPanner.h` | custom stereo panner |

### Building

Open the JUCE project:

```text
juce/NoteDance.jucer
```

or use the generated Visual Studio projects:

```text
juce/Builds/VisualStudio2022/NoteDance.sln
juce/Builds/VisualStudio2026/NoteDance.sln
```

Build either:

- `NoteDance_StandalonePlugin`
- `NoteDance_VST3`

## Testing the JUCE OSC Control

The JUCE plugin currently listens for test messages on port `9001`:

```text
/accel x y
```

Use the included tester:

```bash
cd bridge
python3 osc_juce_test.py
```

Drag inside the XY pad:

- horizontal movement controls pan
- vertical movement changes pitch

## Integration Note

There are currently two reliable demo paths:

1. **SuperCollider demo:** `bridge.py` + `cmls_proj.scd`
2. **JUCE demo:** `osc_juce_test.py` + NoteDance plugin

The full Python bridge sends SC-style OSC addresses such as `/sensor/accel`, `/sensor/tilt`, and `/sensor/shake`. The JUCE plugin currently listens for the simpler `/accel x y` test message.

For full SC/JUCE integration, the next step is to either update the JUCE receiver to parse the bridge messages, or make the bridge also send `/accel x y` to the JUCE plugin.

## Hardware Notes

The Arduino-side serial format expected by `bridge.py` is:

```text
x,y,z\n
```

Values should be acceleration in g units. The current notes assume an MMA7361 3-axis analog accelerometer wired to Arduino analog inputs A0, A1, and A2.

## Team Workflow

- Keep `main` demo-ready.
- Use small feature branches.
- Coordinate before changing OSC address names or argument types.
- Update this README when the SC/JUCE protocol changes.

## How To Run

1. Download the `Supercollider`, `JUCE` and `Arduino` 
2. Download a virtual audio driver, like `VB-CABLE` or `BlackHole Audio`
3. Compile the `AudioPluginHost.jucer` from `.\JUCE\extras\AudioPluginHost` and open `AudioPluginHost.exe`
4. Use the existed `NoteDance.vst3` or Compile the `NoteDance.jucer` from `.\NoteDance\juce` and open `NoteDance.vst3` and link it to `AudioPluginHost.exe`
5. Set the output audio of SC as the input of JUCE
6. Open the `cmls_proj.scd` and run it block by block
7. Upload the code on the Arduino board
8. Turn on the board on top of the car to start sending data to the SC and the Juce plugin
// =====================================================================
// CMLS Project - SuperCollider car-sound source
//
// Always-on car soundscape, split hard across the stereo field:
//   - engine sound       -> LEFT  output channel   (from engine.scd)
//   - drifting drone      -> RIGHT output channel
//   - turn-signal melody  -> RIGHT output channel   (triggered, not always-on)
//
// The stereo split is the whole point: a downstream JUCE plugin pitch-shifts
// the LEFT channel (engine only) and bypasses the RIGHT channel, so the turn
// signal and drift are never touched by the engine processing.
//
//   controlMode \standaloneSC : sensor motion reshapes the SC sound directly.
//   controlMode \pluginSource : SC stays a stable source; the plugin reacts.
// =====================================================================

// ---------- 0. Server config ----------
// Evaluate this block, boot the server, then wait until the server is ready.
(
s.options.numOutputBusChannels = 2;
s.options.numInputBusChannels  = 2;
s.options.sampleRate           = 48000;
s.options.memSize              = 2.pow(16);
)

s.boot;


// ---------- 1. Globals, params, and sensor state ----------
(
~controlMode = \standaloneSC; // \standaloneSC or \pluginSource
// ~controlMode = \pluginSource;

~params = (
    masterAmp:        0.5,
    rootMidi:         60,     // C4, drift fundamental
    tempoBpm:         96,
    minTempoBpm:      58,
    maxTempoBpm:      142,
    pitchBendSemis:   12,
    maxTiltRad:       1.0,
    minCutoff:        700,
    maxCutoff:        5200,
    shakeMax:         0.18,
    tiltPitchPolarity: 1,     // set to -1 if the board feels inverted
    rollPanPolarity:   1,     // set to -1 if left/right feels inverted
    // --- turn signal ---
    turnSpeed:        1.0,    // blink-clock tempo; 1.0 ~= one "people-people" per 0.9 s
    turnThreshold:    0.35,   // |rollNorm| above this auto-triggers a turn
    turnFromRoll:     true,   // derive turn left/right from board roll
    turnAmp:          0.36,
    // --- engine ---
    engineIdleSpeed:  0.34,   // engineSpeed at rest (0..1)
    engineMaxSpeed:   0.9     // engineSpeed under full activity
);

~sensor = (
    accel:       [0, 0, 0],
    roll:        0,
    pitch:       0,
    shake:       0,
    pitchNorm:   0,
    rollNorm:    0,
    pitchSemis:  0,
    pan:         0,
    cutoff:      1600,
    intensity:   0,
    accelEnergy: 0,
    tempoBpm:    ~params.tempoBpm,
    turn:        0,           // -1 left, 0 straight, +1 right
    noteAmp:     0.42
);

~clip = { |value, lo, hi| value.max(lo).min(hi) };
~linlinClip = { |value, inLo, inHi, outLo, outHi|
    var clipped = ~clip.value(value, inLo, inHi);
    clipped.linlin(inLo, inHi, outLo, outHi);
};

~srcGroup  = Group.new(s);
~mixGroup  = Group.after(~srcGroup);
~engineBus = Bus.audio(s, 2);   // engine voice -> mixed to LEFT
~otherBus  = Bus.audio(s, 2);   // drift + turn -> mixed to RIGHT
)


// ---------- 2. SynthDefs ----------
(
// 2.0 Engine voice lives in engine.scd (kept as the single source of truth).
//     Auto-load it from the same folder so SynthDef(\engine) is registered.
if(thisProcess.nowExecutingPath.notNil) {
    (thisProcess.nowExecutingPath.dirname +/+ "engine.scd").load;
} {
    "[cmls] Could not locate engine.scd automatically - evaluate engine.scd by hand.".warn;
};

// 2.1 Drift voice: the old static drone, now slowly drifting in pitch/level/timbre.
SynthDef(\driftVoice, { |out = 0, freq = 220, amp = 0.3, gate = 1, pan = 0, cutoff = 1600|
    var sig, env, detune, freqDrift, ampDrift, cutoffDrift;
    // very low-frequency modulators -> a subtle "floating" feel, never obvious
    freqDrift   = SinOsc.kr(0.05, 0).range(-0.006, 0.006);      // +-0.6% pitch wander
    ampDrift    = SinOsc.kr(0.07, 1.5 * pi).range(0.82, 1.0);   // gentle level swell
    cutoffDrift = LFNoise1.kr(0.08).range(-250, 250);           // slow timbral float
    detune      = LFNoise2.kr(0.15 ! 4).range(-0.4, 0.4);
    sig = Mix.fill(4, { |i|
        SinOsc.ar(freq.lag(0.2) * (1 + freqDrift) * (i + 1) + detune[i]) * (1 / (i + 1.7))
    });
    sig = sig + (Saw.ar(freq.lag(0.2) * [1.0, 1.005]).sum * 0.035);
    sig = LPF.ar(sig, (cutoff.lag(0.25) + cutoffDrift).clip(120, 12000));
    env = EnvGen.kr(Env.asr(1.5, 1, 1.2), gate, doneAction: 2);
    Out.ar(out, Pan2.ar(sig * env * amp.lag(0.1) * ampDrift, pan.lag(0.1)));
}).add;

// 2.2 Turn-signal blink: short, bright "beep" with a tick attack.
//     Two of these in a row make the "peo-ple" pair.
SynthDef(\turnBlink, { |out = 0, freq = 880, amp = 0.4, pan = 0|
    var sig, env, click;
    env   = EnvGen.kr(Env.perc(0.006, 0.11, 1, -4), doneAction: 2);
    sig   = (SinOsc.ar(freq) * 0.6) + (Pulse.ar(freq, 0.35) * 0.22);
    click = HPF.ar(WhiteNoise.ar, 2500) * EnvGen.kr(Env.perc(0.001, 0.012)) * 0.18;
    sig   = LPF.ar((sig * env) + click, 5200);
    Out.ar(out, Pan2.ar(sig * amp, pan));
}).add;

// 2.3 Spare melody voice (kept from the original file for future "other sounds").
SynthDef(\plucky, { |out = 0, freq = 440, amp = 0.45, dur = 0.4, pan = 0, cutoff = 4200|
    var sig, env, exciter;
    exciter = WhiteNoise.ar(1) * EnvGen.kr(Env.perc(0.001, 0.02));
    sig = Pluck.ar(exciter, Impulse.kr(0), 0.05, 1 / freq, dur, 0.52);
    sig = sig + (SinOsc.ar(freq) * 0.18 * EnvGen.kr(Env.perc(0.004, 0.15)));
    sig = LPF.ar(sig, cutoff);
    env = EnvGen.kr(Env.linen(0.005, dur, 0.1), doneAction: 2);
    Out.ar(out, Pan2.ar(sig * env * amp, pan));
}).add;

// 2.4 Master out: engine -> LEFT, everything else -> RIGHT, then limit.
SynthDef(\mainOut, { |engineIn, otherIn, out = 0, amp = 0.5,
    engineAmp = 1.0, otherAmp = 1.0|
    var eng = In.ar(engineIn, 2).sum * 0.5;   // engine summed to mono
    var oth = In.ar(otherIn,  2).sum * 0.5;   // drift + turn summed to mono
    var stereo = [eng * engineAmp, oth * otherAmp];
    Out.ar(out, Limiter.ar(stereo * amp.lag(0.1), 0.95));
}).add;
)


// ---------- 3. Sensor mapping ----------
(
~engineSpeedFor = {
    var activity = ~sensor.intensity.max(~sensor.accelEnergy);
    ~linlinClip.value(activity, 0, 1, ~params.engineIdleSpeed, ~params.engineMaxSpeed);
};

~refreshBrightness = {
    var activity;
    activity = ~sensor.intensity.max(~sensor.accelEnergy * 0.5);
    ~sensor.cutoff = ~linlinClip.value(
        activity, 0, 1, ~params.minCutoff, ~params.maxCutoff
    );
    ~sensor.noteAmp = 0.32 + (activity * 0.24);
};

~applyStandaloneControl = {
    var driftFreq;
    if(~controlMode == \standaloneSC) {
        driftFreq = (~params.rootMidi + ~sensor.pitchSemis).midicps;
        ~drift !? {
            ~drift.set(
                \freq, driftFreq,
                \pan, ~sensor.pan,
                \cutoff, ~sensor.cutoff,
                \amp, 0.26 + (~sensor.intensity * 0.16)
            );
        };
        ~engine !? { ~engine.set(\engineSpeed, ~engineSpeedFor.value) };
    };
};

// Map board roll to a discrete turn state and feed it to the turn controller.
~deriveTurnFromRoll = { |rollNorm|
    var t = if(rollNorm.abs < ~params.turnThreshold) { 0 } { rollNorm.sign };
    ~setTurn.value(t);
};

~updateFromTilt = { |roll, pitch|
    var pitchNorm, rollNorm;
    ~sensor.roll = roll;
    ~sensor.pitch = pitch;

    pitchNorm = ~clip.value((pitch / ~params.maxTiltRad) * ~params.tiltPitchPolarity, -1, 1);
    rollNorm  = ~clip.value((roll  / ~params.maxTiltRad) * ~params.rollPanPolarity, -1, 1);

    ~sensor.pitchNorm  = pitchNorm;
    ~sensor.rollNorm   = rollNorm;
    ~sensor.pitchSemis = (pitchNorm * ~params.pitchBendSemis).round(0.1);
    ~sensor.pan        = rollNorm;
    ~sensor.tempoBpm   = ~linlinClip.value(
        pitchNorm, -1, 1, ~params.minTempoBpm, ~params.maxTempoBpm
    );

    ~applyStandaloneControl.value;

    if((~controlMode == \standaloneSC) and: { ~params.turnFromRoll }) {
        ~deriveTurnFromRoll.value(rollNorm);
    };
};

~updateFromShake = { |magnitude|
    var shakeNorm;
    shakeNorm = ~clip.value(magnitude / ~params.shakeMax, 0, 1);
    ~sensor.shake     = magnitude;
    ~sensor.intensity = shakeNorm;
    ~refreshBrightness.value;
    ~applyStandaloneControl.value;
};

~updateFromAccel = { |x, y, z|
    var accelMagnitude;
    ~sensor.accel = [x, y, z];
    accelMagnitude = ((x * x) + (y * y) + (z * z)).sqrt;
    ~sensor.accelEnergy = ~clip.value((accelMagnitude - 0.25) / 0.75, 0, 1);
    ~refreshBrightness.value;
    ~applyStandaloneControl.value;
};
)


// ---------- 4. Turn signal + start/stop ----------
(
// Pitch pair for the "peo-ple" blink; a right turn rings higher than a left one.
~turnFreqA = { if(~sensor.turn >= 0) { 880 } { 660 } };
~turnFreqB = { ~turnFreqA.value * 1.18 };

// "people-people": two quick blinks (peo-ple), then a rest, repeating forever.
Pdef(\cmlsTurn, Pbind(
    \instrument, \turnBlink,
    \out,  Pfunc { ~otherBus.index },
    \type, Pseq([\note, \note, \rest], inf),
    \freq, Pseq([Pfunc { ~turnFreqA.value }, Pfunc { ~turnFreqB.value }, 1], inf),
    \dur,  Pseq([0.14, 0.16, 0.60], inf),
    \amp,  Pfunc { ~params.turnAmp },
    \pan,  0
));

~startTurnPattern = {
    ~turnClock ?? { ~turnClock = TempoClock.new(~params.turnSpeed) };
    ~turnClock.tempo = ~params.turnSpeed;
    Pdef(\cmlsTurn).play(~turnClock, quant: 0);
};

~stopTurnPattern = { Pdef(\cmlsTurn).stop };

// Drive the turn state. value: <0 left, 0 straight, >0 right.
~setTurn = { |value|
    var v = value.sign;
    var was = ~sensor.turn;
    ~sensor.turn = v;
    if((was == 0) and: { v != 0 }) {
        ~master !? { ~startTurnPattern.value };   // begin blinking (only while playing)
    };
    if((was != 0) and: { v == 0 }) {
        ~stopTurnPattern.value;                    // back to straight -> stop
    };
    // direction flip while already blinking: pattern keeps running, pitch follows
};

~start = {
    ~stop.value;

    ~master = Synth(\mainOut,
        [\engineIn, ~engineBus, \otherIn, ~otherBus, \out, 0, \amp, ~params.masterAmp],
        ~mixGroup
    );

    // engine -> LEFT
    ~engine = Synth(\engine,
        [\outBus, ~engineBus, \engineSpeed, ~engineSpeedFor.value],
        ~srcGroup
    );

    // drifting drone -> RIGHT (always on)
    ~drift = Synth(\driftVoice,
        [
            \out, ~otherBus,
            \freq, ~params.rootMidi.midicps,
            \amp, 0.3,
            \pan, 0,
            \cutoff, if(~controlMode == \standaloneSC) { ~sensor.cutoff } { 1600 }
        ],
        ~srcGroup
    );

    ~applyStandaloneControl.value;

    // if a turn was already requested before playback started, begin blinking now
    if(~sensor.turn != 0) { ~startTurnPattern.value };

    ["started", \controlMode, ~controlMode, \turn, ~sensor.turn].postln;
};

~stop = {
    Pdef(\cmlsTurn).stop;
    ~drift  !? { ~drift.free;  ~drift  = nil };
    ~engine !? { ~engine.free; ~engine = nil };
    ~turnClock !? { ~turnClock.stop; ~turnClock = nil };
    ~master !? { ~master.free; ~master = nil };
    ~sensor.turn = 0;
};
)


// ---------- 5. OSC interface ----------
// The Python bridge (bridge.py) sends:
//   /sensor/accel x y z       floats, normalized to -1..1
//   /sensor/tilt  roll pitch  floats, radians
//   /sensor/shake magnitude   float
//
// Turn signal can be driven two ways:
//   * automatically, from board roll (when turnFromRoll is true), or
//   * explicitly, via /sensor/turn  <value>  (<0 left, 0 straight, >0 right).
(
~oscHandlers !? { ~oscHandlers.do(_.free) };

~oscHandlers = [
    OSCdef(\sensorAccel, { |msg|
        ~updateFromAccel.value(msg[1], msg[2], msg[3]);
    }, '/sensor/accel'),

    OSCdef(\sensorTilt, { |msg|
        ~updateFromTilt.value(msg[1], msg[2]);
    }, '/sensor/tilt'),

    OSCdef(\sensorShake, { |msg|
        ~updateFromShake.value(msg[1]);
    }, '/sensor/shake'),

    OSCdef(\sensorTurn, { |msg|
        ~setTurn.value(msg[1]);
    }, '/sensor/turn'),

    OSCdef(\setMaster, { |msg|
        ~params.masterAmp = msg[1];
        ~master !? { ~master.set(\amp, msg[1]) };
    }, '/control/master/amp'),

    OSCdef(\setRoot, { |msg|
        ~params.rootMidi = msg[1];
        ~drift !? { ~drift.set(\freq, msg[1].midicps) };
        ~applyStandaloneControl.value;
    }, '/control/root/midi')
];
)


// ---------- 6. Manual run order ----------
// 1) Evaluate block 0, run s.boot, wait until the server is ready.
// 2) Evaluate blocks 1, 2, 3, 4, 5 in order.
//    (Block 2 auto-loads engine.scd; if it warns, evaluate engine.scd by hand.)
// 3) ~start.value;                 -- start the car soundscape (engine + drift)
// 4) ~stop.value;                  -- stop everything
// 5) ~oscHandlers.do(_.free);      -- release OSC handlers
//
// Quick turn-signal tests (no hardware needed):
//   ~setTurn.value(1);   -- right turn -> blinking starts on the RIGHT channel
//   ~setTurn.value(-1);  -- left turn  -> blinking continues, lower pitch
//   ~setTurn.value(0);   -- straight   -> blinking stops
//
// Channel map (for the JUCE plugin):
//   LEFT  = engine sound   (pitch-shift / process this one)
//   RIGHT = drift + turn   (bypass - must NOT be pitch-shifted)

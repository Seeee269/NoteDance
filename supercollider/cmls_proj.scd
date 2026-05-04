// =====================================================================
// CMLS Project - SuperCollider-first sensor sound prototype
//
// Current focus:
// - standaloneSC: SuperCollider receives OSC sensor data and controls sound.
// - pluginSource: SuperCollider stays a stable drone/melody source for a
//   future JUCE plugin, while still exposing the same OSC protocol.
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


// ---------- 1. Globals, modes, and sensor state ----------
(
~soundMode = \drone;          // \drone or \melody
// ~soundMode = \melody;

~controlMode = \standaloneSC; // \standaloneSC or \pluginSource
// ~controlMode = \pluginSource;

~params = (
    masterAmp:        0.5,
    rootMidi:         60,     // C4
    scale:            Scale.minorPentatonic,
    tempoBpm:         96,
    minTempoBpm:      58,
    maxTempoBpm:      142,
    pitchBendSemis:   12,
    maxTiltRad:       1.0,
    minCutoff:        700,
    maxCutoff:        5200,
    shakeMax:         0.18,
    tiltPitchPolarity: 1,     // set to -1 if the board feels inverted
    rollPanPolarity:   1      // set to -1 if left/right feels inverted
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
    noteAmp:     0.42
);

~clip = { |value, lo, hi| value.max(lo).min(hi) };
~linlinClip = { |value, inLo, inHi, outLo, outHi|
    var clipped = ~clip.value(value, inLo, inHi);
    clipped.linlin(inLo, inHi, outLo, outHi);
};

~srcGroup = Group.new(s);
~mixGroup = Group.after(~srcGroup);
~mixBus   = Bus.audio(s, 2);
)


// ---------- 2. SynthDefs ----------
(
// 2.1 Drone: stacked harmonics, light detune, controllable pitch/pan/filter.
SynthDef(\droneVoice, { |out = 0, freq = 220, amp = 0.35, gate = 1,
    pan = 0, cutoff = 1600|
    var sig, env, detune;
    detune = LFNoise2.kr(0.15 ! 4).range(-0.35, 0.35);
    sig = Mix.fill(4, { |i|
        SinOsc.ar(freq.lag(0.12) * (i + 1) + detune[i]) * (1 / (i + 1.7))
    });
    sig = sig + (Saw.ar(freq.lag(0.12) * [1.0, 1.005]).sum * 0.035);
    sig = LPF.ar(sig, cutoff.lag(0.18));
    env = EnvGen.kr(Env.asr(1.2, 1, 1.0), gate, doneAction: 2);
    Out.ar(out, Pan2.ar(sig * env * amp.lag(0.08), pan.lag(0.1)));
}).add;

// 2.2 Melody voice: simple pluck tone with live pan/filter/amp parameters.
SynthDef(\plucky, { |out = 0, freq = 440, amp = 0.45, dur = 0.4,
    pan = 0, cutoff = 4200|
    var sig, env, exciter;
    exciter = WhiteNoise.ar(1) * EnvGen.kr(Env.perc(0.001, 0.02));
    sig = Pluck.ar(exciter, Impulse.kr(0), 0.05, 1 / freq, dur, 0.52);
    sig = sig + (SinOsc.ar(freq) * 0.18 * EnvGen.kr(Env.perc(0.004, 0.15)));
    sig = LPF.ar(sig, cutoff);
    env = EnvGen.kr(Env.linen(0.005, dur, 0.1), doneAction: 2);
    Out.ar(out, Pan2.ar(sig * env * amp, pan));
}).add;

// 2.3 Master out: final volume and safety limiting.
SynthDef(\mainOut, { |in, out = 0, amp = 0.5|
    var sig = In.ar(in, 2);
    Out.ar(out, Limiter.ar(sig * amp.lag(0.1), 0.95));
}).add;
)


// ---------- 3. Sensor mapping ----------
(
~refreshBrightness = {
    var activity;
    activity = ~sensor.intensity.max(~sensor.accelEnergy * 0.5);
    ~sensor.cutoff = ~linlinClip.value(
        activity,
        0, 1,
        ~params.minCutoff,
        ~params.maxCutoff
    );
    ~sensor.noteAmp = 0.32 + (activity * 0.24);
};

~applyStandaloneControl = {
    var droneFreq;

    if(~controlMode == \standaloneSC) {
        droneFreq = (~params.rootMidi + ~sensor.pitchSemis).midicps;

        ~drone !? {
            ~drone.set(
                \freq, droneFreq,
                \pan, ~sensor.pan,
                \cutoff, ~sensor.cutoff,
                \amp, 0.28 + (~sensor.intensity * 0.18)
            );
        };

        ~melodyClock !? {
            ~melodyClock.tempo = ~sensor.tempoBpm / 60;
        };
    };
};

~updateFromTilt = { |roll, pitch|
    var pitchNorm, rollNorm;
    ~sensor.roll = roll;
    ~sensor.pitch = pitch;

    pitchNorm = ~clip.value((pitch / ~params.maxTiltRad) * ~params.tiltPitchPolarity, -1, 1);
    rollNorm  = ~clip.value((roll  / ~params.maxTiltRad) * ~params.rollPanPolarity, -1, 1);

    ~sensor.pitchNorm  = pitchNorm;
    ~sensor.rollNorm   = rollNorm;
    ~sensor.pitchSemis = if(~soundMode == \melody) {
        (pitchNorm * ~params.pitchBendSemis).round(1)
    } {
        (pitchNorm * ~params.pitchBendSemis).round(0.1)
    };
    ~sensor.pan        = rollNorm;
    ~sensor.tempoBpm   = ~linlinClip.value(
        pitchNorm,
        -1, 1,
        ~params.minTempoBpm,
        ~params.maxTempoBpm
    );

    ~applyStandaloneControl.value;
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


// ---------- 4. Start / stop helpers ----------
(
~start = {
    var startTempo;

    ~stop.value;
    startTempo = if(~controlMode == \standaloneSC) { ~sensor.tempoBpm } { ~params.tempoBpm };

    ~master = Synth(
        \mainOut,
        [\in, ~mixBus, \out, 0, \amp, ~params.masterAmp],
        ~mixGroup
    );

    if(~soundMode == \drone) {
        ~drone = Synth(
            \droneVoice,
            [
                \out, ~mixBus,
                \freq, ~params.rootMidi.midicps,
                \amp, 0.35,
                \pan, 0,
                \cutoff, if(~controlMode == \standaloneSC) { ~sensor.cutoff } { 1600 }
            ],
            ~srcGroup
        );
    } {
        ~melodyClock = TempoClock.new(startTempo / 60);
        ~melody = Pdef(\cmlsMelody, Pbind(
            \instrument, \plucky,
            \out,        ~mixBus,
            \scale,      Pfunc { ~params.scale },
            \root,       Pfunc { ~params.rootMidi - 60 },
            \octave,     5,
            \degree,     Pseq([0, 2, 4, 2, 5, 4, 2, 0], inf),
            \ctranspose, Pfunc {
                if(~controlMode == \standaloneSC) { ~sensor.pitchSemis } { 0 }
            },
            \dur,        Pseq([0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 1.0], inf),
            \pan,        Pfunc {
                if(~controlMode == \standaloneSC) { ~sensor.pan } { 0 }
            },
            \cutoff,     Pfunc {
                if(~controlMode == \standaloneSC) { ~sensor.cutoff } { 4200 }
            },
            \amp,        Pfunc {
                if(~controlMode == \standaloneSC) { ~sensor.noteAmp } { 0.45 }
            }
        )).play(~melodyClock, quant: 1);
    };

    ~applyStandaloneControl.value;
    ["started", \soundMode, ~soundMode, \controlMode, ~controlMode].postln;
};

~stop = {
    ~drone  !? { ~drone.release; ~drone = nil };
    ~melody !? { Pdef(\cmlsMelody).stop; ~melody = nil };
    ~melodyClock !? { ~melodyClock.stop; ~melodyClock = nil };
    ~master !? { ~master.free; ~master = nil };
};
)


// ---------- 5. OSC interface ----------
// The Python bridge sends:
//   /sensor/accel x y z       floats, normalized to -1..1
//   /sensor/tilt  roll pitch  floats, radians
//   /sensor/shake magnitude   float
//
// In \standaloneSC mode, these messages directly reshape the SC sound.
// In \pluginSource mode, SC ignores sensor motion and stays a stable source.
(
~oscHandlers !? { ~oscHandlers.do(_.free) };

~oscHandlers = [
    OSCdef(\sensorAccel, { |msg|
        var x = msg[1], y = msg[2], z = msg[3];
        ~updateFromAccel.value(x, y, z);
        // [\accel, x, y, z].postln;
    }, '/sensor/accel'),

    OSCdef(\sensorTilt, { |msg|
        var roll = msg[1], pitch = msg[2];
        ~updateFromTilt.value(roll, pitch);
        // [\tilt, roll, pitch, \semitones, ~sensor.pitchSemis].postln;
    }, '/sensor/tilt'),

    OSCdef(\sensorShake, { |msg|
        var magnitude = msg[1];
        ~updateFromShake.value(magnitude);
        // [\shake, magnitude, \cutoff, ~sensor.cutoff].postln;
    }, '/sensor/shake'),

    OSCdef(\setMaster, { |msg|
        ~params.masterAmp = msg[1];
        ~master !? { ~master.set(\amp, msg[1]) };
    }, '/control/master/amp'),

    OSCdef(\setRoot, { |msg|
        ~params.rootMidi = msg[1];
        ~drone !? { ~drone.set(\freq, msg[1].midicps) };
        ~applyStandaloneControl.value;
    }, '/control/root/midi')
];
)


// ---------- 6. Manual run order ----------
// 1) Evaluate block 0, run s.boot, and wait until the server is ready.
// 2) Evaluate blocks 1, 2, 3, 4, 5 in order.
// 3) ~start.value;                 -- start playback
// 4) ~stop.value;                  -- stop playback
// 5) ~oscHandlers.do(_.free);      -- release OSC handlers
//
// Quick switches:
// ~soundMode = \melody; ~start.value;
// ~soundMode = \drone; ~controlMode = \pluginSource; ~start.value;

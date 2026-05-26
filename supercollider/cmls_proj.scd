// =====================================================================
// CMLS Project - SuperCollider car-sound source
//
// Car soundscape, split hard across the stereo field:
//   - engine sound       -> LEFT  output channel   (from engine.scd, always on)
//   - tire/drift sound    -> RIGHT output channel   (triggered by |pan| > threshold)
//   - turn-signal melody  -> RIGHT output channel   (triggered by turn state)
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
    // --- turn signal --- (hysteresis: start above On, end below Off; deadband absorbs jitter)
    turnSpeed:        1.0,    // blink-clock tempo; 1.0 ~= one "people-people" per 0.9 s
    turnOnThreshold:  0.35,   // |rollNorm| above this starts a turn
    turnOffThreshold: 0.25,   // |rollNorm| below this ends it
    turnFromRoll:     true,   // derive turn left/right from board roll
    turnAmp:          0.36,
    // --- drift / tire-skid --- (same hysteresis idea)
    driftOnThreshold:  0.7,   // |pan| above this starts the tire/drift sound
    driftOffThreshold: 0.55,  // |pan| below this stops it
    driftFromPan:      true,  // auto-trigger drift from |pan| (roll) magnitude
    driftAmp:          0.32,  // base level of the drift sound
    // --- engine ---
    engineIdleSpeed:  0.34,   // engineSpeed at rest (0..1)
    engineMaxSpeed:   0.9,    // engineSpeed under full activity
    // --- firmware adapt (Arduino /rotary knob + /accel IMU) ---
    rotaryCenter:     498,    // measured: knob raw when centered
    rotarySpan:       10,     // measured: center->488 right (~10), center->509 left (~11)
    accelPeak:        0.6     // |accel| in g that counts as full engine rev
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

// 2.1 Drift / tire-skid voice: noise-based friction texture with wandering
//     resonant filters + slow random modulation, so it slides/scrapes instead
//     of holding a pitch. Triggered on demand (see ~setDrift), not always-on.
SynthDef(\driftVoice, { |out = 0, amp = 0.32, gate = 1, pan = 0|
    var env, motion, squealFreq, squeal, scrub, rumble, sig;
    // slow random "motion" -> the sound slides and wavers instead of sitting still
    motion     = LFNoise1.kr(0.4).range(0.35, 1.0);
    squealFreq = LFNoise1.kr(0.7).exprange(700, 2600)            // wandering skid pitch
                 * SinOsc.kr(LFNoise1.kr(0.3).range(4, 9), 0, 0.03, 1);  // slight waver
    // high-Q resonant noise = tire squeal / skid
    squeal = BPF.ar(WhiteNoise.ar, squealFreq, 0.12) * 6;
    squeal = squeal * LFNoise1.kr(0.9).range(0.25, 1.0);         // flickering intensity
    // broadband filtered noise = rubber scrubbing on tarmac
    scrub  = BPF.ar(PinkNoise.ar, LFNoise1.kr(0.5).exprange(900, 4200), 0.6) * 1.6;
    // low contact rumble
    rumble = LPF.ar(BrownNoise.ar, 190) * 0.6;
    sig = ((squeal + scrub) * motion) + rumble;
    sig = LeakDC.ar(sig);
    sig = (sig * 0.6).tanh;                                      // soft-clip, stay controlled
    env = EnvGen.kr(Env.asr(0.7, 1, 1.1), gate, doneAction: 2);
    Out.ar(out, Pan2.ar(sig * env * amp.lag(0.1), pan));
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
    if(~controlMode == \standaloneSC) {
        ~drift  !? { ~drift.set(\amp, ~params.driftAmp + (~sensor.intensity * 0.18)) };
        ~engine !? { ~engine.set(\engineSpeed, ~engineSpeedFor.value) };
    };
};

// Map board roll to a turn state, with hysteresis so jitter near the threshold
// doesn't flicker the blinker: start above turnOnThreshold, return to straight
// only below turnOffThreshold; a clean sign change can still flip L<->R.
~deriveTurnFromRoll = { |rollNorm|
    var mag  = rollNorm.abs;
    var cur  = ~sensor.turn;
    var next = cur;
    if(cur == 0) {
        if(mag > ~params.turnOnThreshold) { next = rollNorm.sign };
    } {
        if(mag < ~params.turnOffThreshold) {
            next = 0;
        } {
            if((rollNorm.sign != cur) and: { mag > ~params.turnOnThreshold }) {
                next = rollNorm.sign;
            };
        };
    };
    if(next != cur) { ~setTurn.value(next) };
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

    if(~controlMode == \standaloneSC) {
        if(~params.turnFromRoll) { ~deriveTurnFromRoll.value(rollNorm) };
        if(~params.driftFromPan) { ~setDrift.value(~sensor.pan) };
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

// Drive the drift/tire sound with hysteresis: start when |pan| rises above
// driftOnThreshold, stop only when it falls below driftOffThreshold. The
// deadband between the two keeps real sensor jitter from chattering it on/off.
~setDrift = { |panValue|
    var mag = panValue.abs;
    if(~drift.isNil and: { mag > ~params.driftOnThreshold }) {
        ~master !? {
            ~drift = Synth(\driftVoice,
                [\out, ~otherBus, \amp, ~params.driftAmp, \pan, 0],
                ~srcGroup
            );
            ~applyStandaloneControl.value;
        };
    };
    if(~drift.notNil and: { mag < ~params.driftOffThreshold }) {
        ~drift.release;   // gate 0 -> fade out -> self-free (doneAction 2)
        ~drift = nil;
    };
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

    // drift/tire sound is triggered on demand (see ~setDrift), not started here.

    ~applyStandaloneControl.value;

    // honor anything already requested before playback started
    if(~sensor.turn != 0) { ~startTurnPattern.value };
    ~setDrift.value(~sensor.pan);

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
// Two protocols are accepted:
//   A) Python bridge (bridge.py):
//        /sensor/accel x y z   ·  /sensor/tilt roll pitch  ·  /sensor/shake mag
//        /sensor/turn  <value> (<0 left, 0 straight, >0 right)
//   B) Arduino firmware (LSM6DS3 + Grove rotary), direct OSC:
//        /rotary <raw>      Grove knob ~474..509 (center 492)  -> steering
//        /accel  <ax> <ay>  IMU accel X/Y in g                 -> engine revs
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
    }, '/control/root/midi'),

    // --- Direct firmware protocol (Arduino: /rotary knob + /accel IMU) ---
    // /rotary <raw> : Grove knob. Measured center 498, right turn -> 488 (raw down),
    // left turn -> 509 (raw up). norm: +1 = right, -1 = left, 0 = centered.
    OSCdef(\fwRotary, { |msg|
        var norm = ((~params.rotaryCenter - msg[1]) / ~params.rotarySpan).clip(-1, 1);
        // reuse the existing hysteresis so jitter near a threshold doesn't
        // chatter the turn signal / skid on and off:
        ~deriveTurnFromRoll.value(norm);   // turn signal, hysteresis: on 0.35 / off 0.25
        ~setDrift.value(norm);             // skid,         hysteresis: on 0.7  / off 0.55
    }, '/rotary'),

    // /accel <ax> <ay> : IMU accel X/Y (g) -> engine revs
    OSCdef(\fwAccel, { |msg|
        var energy = ((msg[1] * msg[1]) + (msg[2] * msg[2])).sqrt
            .linlin(0, ~params.accelPeak, 0, 1);
        ~updateFromShake.value(energy * ~params.shakeMax);
    }, '/accel')
];
)


// ---------- 6. Manual run order ----------
// 1) Evaluate block 0, run s.boot, wait until the server is ready.
// 2) Evaluate blocks 1, 2, 3, 4, 5 in order.
//    (Block 2 auto-loads engine.scd; if it warns, evaluate engine.scd by hand.)
// 3) ~start.value;                 -- start the car soundscape (engine; drift/turn on demand)
// 4) ~stop.value;                  -- stop everything
// 5) ~oscHandlers.do(_.free);      -- release OSC handlers
//
// Quick tests (no hardware needed):
//   ~setTurn.value(1);    -- right turn  -> blink starts on the RIGHT channel
//   ~setTurn.value(-1);   -- left turn   -> blink continues, lower pitch
//   ~setTurn.value(0);    -- straight    -> blink stops
//   ~setDrift.value(0.9); -- |pan|>0.7   -> tire/drift sound fades in (RIGHT)
//   ~setDrift.value(0);   -- back inside -> drift fades out
//
// Channel map (for the JUCE plugin):
//   LEFT  = engine sound   (pitch-shift / process this one)
//   RIGHT = drift + turn   (bypass - must NOT be pitch-shifted)

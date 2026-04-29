// =====================================================================
// CMLS Project — Music Source (SuperCollider side)
// 角色：产生稳定的连续音 / 循环旋律，输出到虚拟声卡供 JUCE 插件再加工。
// 传感器响应（pitch / speed）由 JUCE 处理，SC 这边只做稳定的音频源。
// OSC 接口仅用于调试和后期可能的扩展。
// =====================================================================

// ---------- 0. Server config ----------
// 运行前把系统输出设为 BlackHole 2ch（或同类虚拟声卡），
// JUCE 插件宿主的输入设备指向同一个设备 → SC 的声音就进了 JUCE。
(
s.options.numOutputBusChannels = 2;
s.options.numInputBusChannels  = 2;
s.options.sampleRate           = 48000;
s.options.memSize              = 2.pow(16);
)

s.boot;


// ---------- 1. 全局参数 & 模式开关 ----------
(
~mode = \drone;   // \drone 连续音  /  \melody 循环旋律
// ~mode = \melody;

~params = (
    masterAmp: 0.5,
    rootMidi:  60,    // C4
    scale:     Scale.minorPentatonic,
    tempoBpm:  96
);

~srcGroup = Group.new(s);
~mixGroup = Group.after(~srcGroup);
~mixBus   = Bus.audio(s, 2);
)


// ---------- 2. SynthDefs ----------
(
// 2.1 连续音：多谐波 + 轻微解谐 + 缓慢起伏。干净、容易被 pitch/speed 处理
SynthDef(\droneVoice, { |out = 0, freq = 220, amp = 0.4, gate = 1|
    var sig, env, detune;
    detune = LFNoise2.kr(0.15 ! 4).range(-0.4, 0.4);
    sig = Mix.fill(4, { |i|
        SinOsc.ar(freq * (i + 1) + detune[i]) * (1 / (i + 1.6))
    });
    sig = sig + (Saw.ar(freq * [1.0, 1.005]) * 0.08);
    sig = LPF.ar(sig, LFNoise2.kr(0.2).exprange(900, 2200));
    env = EnvGen.kr(Env.asr(1.5, 1, 1.5), gate, doneAction: 2);
    sig = sig * env * amp;
    Out.ar(out, Splay.ar(sig));
}).add;

// 2.2 旋律用单音色：拨弦风格，attack/decay 清晰，便于听出节奏
SynthDef(\plucky, { |out = 0, freq = 440, amp = 0.5, dur = 0.4|
    var sig, env, exciter;
    exciter = WhiteNoise.ar(1) * EnvGen.kr(Env.perc(0.001, 0.02));
    sig = Pluck.ar(exciter, Impulse.kr(0), 0.05, 1 / freq, dur, 0.5);
    sig = sig + (SinOsc.ar(freq) * 0.2 * EnvGen.kr(Env.perc(0.005, 0.15)));
    sig = LPF.ar(sig, 4500);
    env = EnvGen.kr(Env.linen(0.005, dur, 0.1), doneAction: 2);
    sig = sig * env * amp;
    Out.ar(out, sig.dup);
}).add;

// 2.3 主输出（只控制总音量；染色/效果交给 JUCE）
SynthDef(\mainOut, { |in, out = 0, amp = 0.5|
    var sig = In.ar(in, 2);
    Out.ar(out, sig * amp);
}).add;
)


// ---------- 3. 启停 helpers ----------
(
~start = {
    ~master = Synth(\mainOut, [\in, ~mixBus, \out, 0, \amp, ~params.masterAmp], ~mixGroup);

    if(~mode == \drone) {
        // 一个稳定的根音 drone（一直响），JUCE 来变 pitch
        ~drone = Synth(\droneVoice, [
            \out,  ~mixBus,
            \freq, ~params.rootMidi.midicps,
            \amp,  0.35
        ], ~srcGroup);
    } {
        // 简单循环旋律：五声音阶里的 8 音模式
        ~melody = Pdef(\loop, Pbind(
            \instrument, \plucky,
            \out,        ~mixBus,
            \scale,      ~params.scale,
            \root,       ~params.rootMidi - 60,
            \degree,     Pseq([0, 2, 4, 2, 5, 4, 2, 0], inf),
            \dur,        Pseq([0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 1.0], inf),
            \amp,        0.45
        )).play(quant: 1);
    };
};

~stop = {
    ~drone  !? { ~drone.release;  ~drone  = nil };
    ~melody !? { Pdef(\loop).stop; ~melody = nil };
    ~master !? { ~master.release; ~master = nil };
};
)


// ---------- 4. OSC 接口（预留 — 当前只做调试/日志） ----------
// 默认监听 NetAddr.langPort（57120）。
// 桥接脚本同时把数据发到 SC 这个端口和 JUCE 的端口。
// 这里 SC 不响应传感器；要让 SC 也跟着动，在 handler 里 .set 即可。
(
~oscHandlers = [
    OSCdef(\sensorAccel, { |msg|
        var x = msg[1], y = msg[2], z = msg[3];
        // [\\accel, x, y, z].postln;   // 调试时打开
    }, '/sensor/accel'),

    OSCdef(\sensorTilt, { |msg|
        var roll = msg[1], pitch = msg[2];
        // [\\tilt, roll, pitch].postln;
    }, '/sensor/tilt'),

    // 调试：手动改总音量、根音
    OSCdef(\setMaster, { |msg|
        ~params.masterAmp = msg[1];
        ~master !? { ~master.set(\amp, msg[1]) };
    }, '/control/master/amp'),

    OSCdef(\setRoot, { |msg|
        ~params.rootMidi = msg[1];
        ~drone !? { ~drone.set(\freq, msg[1].midicps) };
    }, '/control/root/midi')
];
)


// ---------- 5. 手动逐块运行 ----------
// 1) evaluate 块 0、1、2、3、4
// 2) ~start.value;     启动
// 3) ~stop.value;      停止
// 4) ~oscHandlers.do(_.free);   清理 OSC

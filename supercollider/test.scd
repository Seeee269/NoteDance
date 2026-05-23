// =====================================================================
// CMLS Project - test / demo runner for cmls_proj.scd
//
// One-shot, no-hardware sanity check: boots the server, loads every
// definition from cmls_proj.scd (+ engine.scd), then plays a short demo
// exercising all the sounds — engine idle/throttle, drift, and the
// left/right turn signal — and quits.
//
//   Terminal:  sclang test.scd
//   SC IDE:    save this file, then evaluate the whole ( ... ) block.
//
// cmls_proj.scd stays the interactive "real" project (run block by block);
// this file just drives it automatically for quick listening tests.
// =====================================================================
(
var here, loadDefs;

here = thisProcess.nowExecutingPath !? { |p| p.dirname };
if(here.isNil) {
    "test.scd: save the file first — its path is needed to find cmls_proj.scd.".error;
} {
    // cmls_proj.scd is a block-by-block interactive file, so it cannot be
    // .load-ed as a whole (its top-level ( ) blocks + bare s.boot are not one
    // program). Split on the top-level ( ... ) blocks and interpret each;
    // block 0 is the server config, which we skip (options are set below).
    loadDefs = {
        var lines  = File.readAllString(here +/+ "cmls_proj.scd").split($\n);
        var blocks = List.new, cur = nil;
        lines.do { |ln|
            if(ln == "(") { cur = List.new };
            if(cur.notNil) { cur.add(ln) };
            if((ln == ")") and: { cur.notNil }) {
                blocks.add(cur.join("\n")); cur = nil;
            };
        };
        (here +/+ "engine.scd").load;        // \engine SynthDef
        blocks[1..].do { |b| b.interpret };  // skip block 0 (server config)
    };

    s.options.numOutputBusChannels = 2;
    s.options.numInputBusChannels  = 2;
    s.options.sampleRate           = 48000;
    s.options.memSize              = 2.pow(16);

    s.waitForBoot({
        Routine({
            "=== server booted, loading defs ===".postln;
            loadDefs.value;
            s.sync;
            if(~start.isNil) {
                "!!! ~start undefined - cmls_proj.scd failed to load".error;
                s.quit; 0.exit;
            };
            "=== starting demo ===".postln;
            ~start.value;
            s.sync;

            "[demo] idle (engine only, LEFT)".postln;                    3.wait;
            "[demo] throttle up/down -> engine revs".postln;
            30.do { |i| ~updateFromShake.value(i / 29 * 0.18); 0.07.wait };
            30.do { |i| ~updateFromShake.value((1 - (i / 29)) * 0.18); 0.07.wait };
            "[demo] DRIFT on  (|pan|>0.7 -> tire skid, RIGHT)".postln; ~setDrift.value(0.9); 4.wait;
            "[demo] DRIFT off (back inside)".postln;                   ~setDrift.value(0);   2.wait;
            "[demo] RIGHT turn signal".postln;          ~setTurn.value(1);   3.wait;
            "[demo] LEFT turn signal".postln;           ~setTurn.value(-1);  3.wait;
            "[demo] hard corner: turn + drift".postln;  ~setTurn.value(1); ~setDrift.value(0.9); 4.wait;
            "[demo] straight (all off)".postln;  ~setTurn.value(0); ~setDrift.value(0);  2.wait;
            "[demo] stop".postln;                       ~stop.value;         1.wait;

            "=== done ===".postln;
            s.quit; 0.exit;
        }).play;
    }, 10, { "=== BOOT FAILED (headless / no audio device?) ===".error; 0.exit });
};
)

(
SynthDef(\engine, {
	arg effectOut = 0, engineSpeed = 0.75, outBus = 0;
	var jitterEngine, noise, bufferA, bufferB, fourstroke;

	bufferA = LocalBuf(44100, 1);
	bufferB = LocalBuf(44100, 1);

	noise = WhiteNoise.ar;
	noise = OnePole.ar(noise, exp(-2pi * (20 * SampleDur.ir)));
	noise = OnePole.ar(noise, exp(-2pi * (20 * SampleDur.ir)));
	noise = DelTapWr.ar([bufferA, bufferB], [noise * 0.5, noise * 10]);

	fourstroke = DelTapRd.ar(bufferA, noise[0], [5, 10, 15, 20]/1000);
	fourstroke =
			LFSaw.ar(OnePole.ar((K2A.ar(engineSpeed) * 40), exp(-2pi * (0.8 * SampleDur.ir))), 1, 0.5, 0.5)
		 	 + fourstroke
		 	 - [0.75, 0.5, 0.25, 0];
	fourstroke = (fourstroke * 2pi).cos;

	fourstroke =
			fourstroke
			* (DelTapRd.ar(bufferB, noise[1], [5, 10, 15, 20]/1000) + ((1 - engineSpeed) * 15 + 7));
	fourstroke = 1 / ((fourstroke * fourstroke) + 1);
	fourstroke = fourstroke.sum!2 * 0.25;
	
	Out.ar(outBus, fourstroke);
}).add;
)

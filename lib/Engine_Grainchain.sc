// Engine_Grainchain

// Inherit methods from CroneEngine
Engine_Grainchain : CroneEngine {

	// Grainchain specific v0.1.0
	var server;
	var bufs;
	var buses;
	var syns;
	var oscs;
	var loops;
	// Grainchain ^

	*new { arg context, doneCallback;
		^super.new(context, doneCallback);
	}

	alloc {
		// Grainchain specific v0.0.1
		var server = context.server;

		// basic players
		SynthDef("fx",{
			arg busDry,busWet;
			var snd;
			var in = SoundIn.ar([0,1])*(\db_in.kr(0).dbamp);
			var sndDry = In.ar(busDry,2);
			var sndWet = In.ar(busWet,2);
			sndWet = (sndWet+(in*0.2));
			sndWet=Fverb.ar(sndWet[0],sndWet[1]);

			snd = in + sndDry + sndWet;
			Out.ar(0,snd*Line.ar(0,1,3));
		}).add;

		SynthDef("recorder",{
			arg buf,gate=1;
			var snd = SoundIn.ar([0,1]);
			snd = snd * EnvGen.ar(Env.adsr(1,1,1,1),gate:gate,doneAction:2);
			RecordBuf.ar(snd,buf,loop:0,doneAction:2);
			Out.ar(0,Silent.ar(2));
		}).add;


		// initialize variables
		syns = Dictionary.new();
		buses = Dictionary.new();
		bufs = Dictionary.new();
		oscs = Dictionary.new();
		loops = Dictionary.new();

		server.sync;
		oscs.put("loop_db",OSCFunc({ |msg|
			// var oscRoute=msg[0];
			// var synNum=msg[1];
			// var dunno=msg[2];
			// var id=msg[3].asInteger;
			// var db=msg[4].asFloat.ampdb;
			// NetAddr("127.0.0.1", 10111).sendMsg("loop_db",id,db);
		}, '/loop_db'));
		
		// define buses
		buses.put("busDry",Bus.audio(server,2));
		buses.put("busReverb",Bus.audio(server,2));
		server.sync;

		// main out
		syns.put("fx",Synth.tail(server,"fx",[
			busDry: buses.at("busDry"),
			busReverb: buses.at("busReverb"),
		]));
		server.sync;

		"done loading.".postln;

		this.addCommand("record_start","is",{ arg msg;
			var id=msg[1];
			var fname=msg[2].asString;
			var seconds=60;

			// allocate buffer and record the loop
			Buffer.alloc(server,seconds*server.sampleRate,2,completionMessage:{ arg buf;
				var timeStart = Date.getDate;
				["[record] started recording loop",fname].postln;
				syns.put("recording",Synth.head(server,"recorder",[
					buf: buf,
				]).onFree({
					var timeEnd = Date.getDate;
					var duration=(timeEnd.rawSeconds-timeStart-rawSeconds);
					["[record] finished recording loop",fname,"for",duration,"seconds"].postln;
					Buffer.write(fname,numFrames:duration*server.sampleRate,completionMessage:{
						["[record] finished writing",fname].postln;
						NetAddr("127.0.0.1", 10111).sendMsg("recorded",id,fname);
					});
				}));
				NodeWatcher.register(syns.at("recording"));
			});
		});

		this.addCommand("record_stop","",{ arg msg;
			if (syns.at("recording").notNil,{
				if (syns.at("recording").isRunning,{
					syns.at("recording").set(\gate,0);
				});
			});
		});

		this.addCommand("set_val","isf",{ arg msg;
			var id=msg[1];
			var k=msg[2];
			var v=msg[3];
		});
	}


	free {
		bufs.keysValuesDo({ arg k, val;
			val.free;
		});
		oscs.keysValuesDo({ arg k, val;
			val.free;
		});
		syns.keysValuesDo({ arg k, val;
			val.free;
		});
		loops.keysValuesDo({ arg k, val;
			val.free;
		});
		buses.keysValuesDo({ arg k, val;
			val.free;
		});
	}
}

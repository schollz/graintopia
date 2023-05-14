// Engine_Graintopia

// Inherit methods from CroneEngine
Engine_Graintopia : CroneEngine {

	// Graintopia specific v0.1.0
	var server;
	var params;
	var bufs;
	var buses;
	var syns;
	var oscs;
	var lands;
	// Graintopia ^

	landPlay {
		arg land=1,buf;

		6.do({ arg i;
			var player=i+1;
			var syn=Synth.head(server,"looper"++buf.numChannels,[
				\land,land,
				\player,player,
				\buf,buf,
				\busDry,buses.at("busDry")
				,\busWet,buses.at("busWet"),
			]).onFree({
				("[landPlay] land"+land+", player"+player+"finished.").postln;				
			});
			("[landPlay] land"+land+", player"+player+"started.").postln;				
			if (lands.at(land).at(player).notNil,{
				if (lands.at(land).at(player).isRunning,{
					lands.at(land).at(player).set(\gate,0); // turn off
				});
			});
			// update with current volumes, etc
			params.at(player).keysValuesDo({ arg k, val;
				syn.set(k,val);
			});
			lands.at(land).put(player,syn);
			NodeWatcher.register(syn);
		});
	}

	*new { arg context, doneCallback;
		^super.new(context, doneCallback);
	}

	alloc {
		// Graintopia specific v0.0.1
		var server = context.server;

		// looper 

		2.do({ arg i;
		var numChannels=i+1;
		SynthDef("looper"++numChannels,{
			// main arguments
			arg busWet,busDry,wet=0.5,buf,land,player,baseRate=1.0,rateMult=1.0,db=0.0,timescalein=1,posStart=0,posEnd=1,gate=1,ampNum=1,rateSlew=1.0;
			// variables to store UGens later
			var amp = Lag.kr(db.dbamp,1);
			var volume;
			var switch=0,snd,snd1,snd2,pos,pos1,pos2,index;
			// store the number of frames and the duration
			var frames=BufFrames.kr(buf);
			var duration=BufDur.kr(buf);
			var timescale = timescalein / duration * 5;
			// LFO for the rate (right now its not an LFO)
			//var lfoRate=baseRate*rateMult;//*Select.kr(SinOsc.kr(1/Rand(10,30)).range(0,4.9),[1,0.25,0.5,1,2]);
			var lfoRateAmp=Demand.kr(Impulse.kr(0)+Dust.kr(timescale/Rand(10,30)),0,
				Dwrand([0,1,2,3,4,5],[14,8,3,6,4]/35,inf)
			);
			var lfoRate=Select.kr(lfoRateAmp,[1,2  ,4,   0.5, 0.25]);
			var lfoAmp2=Select.kr(lfoRateAmp,[1,0.5,0.2,1.25, 1.5]);
			// LFO for switching between forward and reverse <-- tinker
			var lfoForward=Demand.kr(Impulse.kr(timescale/Rand(5,15)),0,Drand([0,1],inf));
			// LFO for the volume <-- tinker
			var lfoAmp=SinOsc.kr(timescale/Rand(5,10),Rand(hi:2*pi)).range(0.25,1);
			// LFO for the panning <-- tinker
			var lfoPan=SinOsc.kr(timescale/Rand(10,30),Rand(hi:2*pi)).range(0.5.neg,0.5);

			// calculate the final rate
			var rate=Lag.kr(lfoRate*(2*lfoForward-1),rateSlew)*BufRateScale.kr(buf);

			// set the start/end points
			posStart = Clip.kr(LinLin.kr(posStart,0,1,0,frames),1024,frames-10240);
			posEnd = Clip.kr(LinLin.kr(posEnd,0,1,0,frames),posStart+1024,frames-1024);

			// LocalIn collects the a trigger whenever the playhead leaves the window
			switch=ToggleFF.kr(LocalIn.kr(1));

			// playhead 1 has a play position and buffer reader
			pos1=Phasor.ar(trig:1-switch,rate:rate,end:frames,resetPos:((lfoForward>0)*posStart)+((lfoForward<1)*posEnd));
			snd1=BufRd.ar(numChannels,buf,pos1,1.0,4);

			// playhead 2 has a play position and buffer reader
			pos2=Phasor.ar(trig:switch,  rate:rate,end:frames,resetPos:((lfoForward>0)*posStart)+((lfoForward<1)*posEnd));
			snd2=BufRd.ar(numChannels,buf,pos2,1.0,4);

			// current position changes according to the swtich
			pos=Select.ar(switch,[pos1,pos2]);

			// send out a trigger anytime the position is outside the window
			LocalOut.kr(
				Changed.kr(Stepper.kr(Impulse.kr(10),max:1000000000,
					step:(pos>posEnd)+(pos<posStart)
				))
			);

			// crossfade bewteen the two sounds over 50 milliseconds
			snd=SelectX.ar(Lag.kr(switch,0.05),[snd1,snd2]);

			// apply the volume lfo
			volume = lfoAmp*EnvGen.ar(Env.new([0,1],[Rand(1,10)],4));
			// apply the start/stop envelope
			volume = volume * EnvGen.ar(Env.adsr(1,1,1,1),gate,doneAction:2);
			// apply num amp 
			volume = volume * EnvGen.ar(Env.adsr(Rand(1,3),1,1,Rand(1,3)),ampNum);

			// send data to the GUI
			SendReply.kr(Impulse.kr(10),"/position",[land,player,posStart/frames,posEnd/frames,LinLin.kr(pos/frames,0,1,1,127).round,LinLin.kr(volume,0,1,1,8).round,lfoPan*2]);

			// do the panning
			if (numChannels>1,{
				snd=Balance2.ar(snd[0],snd[1],lfoPan);
			},{
				snd=Pan2.ar(snd,lfoPan);
			});

			// final output
			snd = snd * volume / 15 * amp * Lag.kr(lfoAmp2,Rand(0.1,0.7));
			Out.ar(busWet,snd*wet);
			Out.ar(busDry,snd*(1-wet));
		}).add;
		});

		// basic players
		SynthDef("fx",{
			arg busDry,busWet;
			var snd;
			var in = SoundIn.ar([0,1])*(\db_in.kr(0).dbamp);
			var sndDry = In.ar(busDry,2);
			var sndWet = In.ar(busWet,2);
			// sndWet = (sndWet+(in*0.2));
			sndWet=Fverb.ar(sndWet[0],sndWet[1],50,decay:LFNoise2.kr(1/4).range(70,90));

			snd = in + sndDry + sndWet;
			Out.ar(0,snd*Line.ar(0,1,3));
		}).add;

		SynthDef("recorder",{
			arg buf,gate=1;
			var snd = SoundIn.ar([0,1]);
			snd = snd * 10 * EnvGen.ar(Env.adsr(0.05,1,1,0.05),gate:gate,doneAction:2);
			RecordBuf.ar(snd.tanh,buf,loop:0,doneAction:2);
			Out.ar(0,Silent.ar(2));
		}).add;


		// initialize variables
		params = Dictionary.new();
		syns = Dictionary.new();
		buses = Dictionary.new();
		bufs = Dictionary.new();
		oscs = Dictionary.new();
		lands = Dictionary.new();
		// each land has 6 players
		6.do({arg i;
			var player = i+1; // 1-index
			lands.put(player,Dictionary.new());
			params.put(player,Dictionary.new());
		});

		server.sync;
		oscs.put("loop_db",OSCFunc({ |msg|
			// var oscRoute=msg[0];
			// var synNum=msg[1];
			// var dunno=msg[2];
			// var id=msg[3].asInteger;
			// var db=msg[4].asFloat.ampdb;
			// NetAddr("127.0.0.1", 10111).sendMsg("loop_db",id,db);
		}, '/loop_db'));
		oscs.put("position",OSCFunc({ |msg|
			var oscRoute=msg[0];
			var synNum=msg[1];
			var dunno=msg[2];
			var land=msg[3].asInteger;
			var player=msg[4].asInteger;
			var posStart=msg[5];
			var posEnd=msg[6];
			var pos=msg[7];
			var volume=msg[8];
			var pan=msg[9];
			NetAddr("127.0.0.1", 10111).sendMsg("position",land,player,pos);
			// NetAddr("127.0.0.1", 10111).sendMsg("posStart",land,player,posStart);
			// NetAddr("127.0.0.1", 10111).sendMsg("posEnd",land,player,posEnd);
			NetAddr("127.0.0.1", 10111).sendMsg("volume",land,player,volume);
			NetAddr("127.0.0.1", 10111).sendMsg("pan",land,player,pan);
		}, '/position'));
		
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
					var duration=(timeEnd.rawSeconds-timeStart.rawSeconds);
					["[record] finished recording loop",fname,"for",duration,"seconds"].postln;
					buf.write(fname,headerFormat: "wav", sampleFormat: "int16",numFrames:duration*server.sampleRate,completionMessage:{
						["[record] finished writing",fname].postln;
						Routine{
							1.wait;
							NetAddr("127.0.0.1", 10111).sendMsg("recorded",id,fname);
						}.play;
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

		
		this.addCommand("set_player","iisf",{ arg msg;
			var land=msg[1];
			var player=msg[2];
			var k=msg[2].asSymbol;
			var v=msg[3];
			if (lands.at(land).at(player).notNil,{
				if (lands.at(land).at(player).isRunning,{
					lands.at(land).at(player).set(k,v);
				});
			});
		});

		this.addCommand("land_set_endpoints","iffffffffffff",{ arg msg;
			var land=msg[1];
			6.do({arg i;
				var player=i+1;
				if (lands.at(land).at(player).notNil,{
					if (lands.at(land).at(player).isRunning,{
						lands.at(land).at(player).set(\posStart,msg[player*2]);
						lands.at(land).at(player).set(\posEnd,msg[player*2+1]);
					});
				});
			});
		});

		
		this.addCommand("land_set","isf",{ arg msg;
			var land=msg[1];
			var k=msg[2].asSymbol;
			var v=msg[3];
			params.at(land).put(k,v);
			6.do({ arg i;
				var player=i+1;
				if (lands.at(land).at(player).notNil,{
					if (lands.at(land).at(player).isRunning,{
						lands.at(land).at(player).set(k,v);
					});
				});
			});
		});
		
		this.addCommand("land_set_num","ii",{ arg msg;
			var land=msg[1];
			var num=msg[2];
			6.do({ arg i;
				var player=i+1;
				if (lands.at(land).at(player).notNil,{
					if (lands.at(land).at(player).isRunning,{
						if (player<=num,{
							1.postln;
							lands.at(land).at(player).set(\ampNum,1);
						},{
							0.postln;
							lands.at(land).at(player).set(\ampNum,0);
						});
					});
				});
			});
		});


		this.addCommand("land_load","is",{ arg msg;
			var land=msg[1];
			var fname=msg[2].asString;
			Buffer.read(server,fname,action:{ arg buf;
				("[land_load] loaded"+land+fname).postln;
				bufs.put(fname,buf);
				this.landPlay(land,buf);
			});
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
		lands.keysValuesDo({ arg k, lands_syns;
			lands_syns.keysValuesDo({ arg k2, val;
				val.free;
			});
		});
		buses.keysValuesDo({ arg k, val;
			val.free;
		});
	}
}

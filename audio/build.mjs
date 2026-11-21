// Builds the two WebAssembly modules of the ROM tool's sound generator (node audio/build.mjs):
//   rom-tool/sound/wasm/engine.js  the game's own audio engine (the decomp's src/audio, unmodified) with the host of audio/native
//   rom-tool/sound/wasm/vorbis.js an Ogg Vorbis encoder (Emscripten's libogg and libvorbis ports)
// Each is a single ES module with its WebAssembly inside. Needs the Emscripten SDK (emcc on PATH, or EMCC) and the decompilation
// checked out in reference/. The modules are committed: only a change of audio/native needs this build.
import { spawnSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

const Audio = path.dirname(fileURLToPath(import.meta.url));
const Root = path.join(Audio, "..");
const Reference = path.join(Root, "reference");
const Native = path.join(Audio, "native");
const Output = path.join(Root, "rom-tool", "sound", "wasm");

const Emcc = process.env.EMCC ?? "emcc";

function Emscripten(args) {
	// emcc is a batch file on Windows, which only runs through a shell: the arguments (paths with spaces) are quoted
	const windows = process.platform === "win32";
	const result = spawnSync(Emcc, windows ? args.map((Argument) => `"${Argument}"`) : args, { stdio: "inherit", shell: windows });

	if (result.status !== 0) {
		throw new Error(`emcc failed (${result.status ?? result.error})`);
	}
}

const Module = [
	"-sMODULARIZE",
	"-sEXPORT_ES6",
	"-sSINGLE_FILE",
	"-sENVIRONMENT=web,worker,node",
	"-sALLOW_MEMORY_GROWTH",
	"-sFILESYSTEM=0",
	"-sEXPORTED_RUNTIME_METHODS=HEAPU8,HEAPF64",
	"--no-entry",
	"-O2",
];

// The decomp audio engine, unmodified, plus the host (host.c), the microcode commands (mixer.c) and synthesis.c compiled through
// synthesis_hle.c. -D_OS_H_ drops PR/os.h, whose prototypes clash with the ones of ultra64.h on a non N64 build.
Emscripten([
	"-std=gnu90",
	"-fsigned-char",
	"-fno-strict-aliasing",
	"-fwrapv",
	"-ffp-contract=off",
	"-fcommon",
	"-w",
	"-D_OS_H_",
	"-DVERSION_US=1",
	"-DNON_MATCHING=1",
	"-DAVOID_UB=1",
	"-D_FINALROM=1",
	"-D_LANGUAGE_C",
	"-DNO_SEGMENTED_MEMORY",
	`-I${Reference}/include`,
	`-I${Reference}/src`,
	`-I${Reference}`,
	`-I${Native}`,
	`-I${Reference}/lib`,
	`-I${Reference}/lib/include`,
	...["data", "effects", "external", "heap", "load", "playback", "seqplayer"].map((Name) => path.join(Reference, "src", "audio", `${Name}.c`)),
	path.join(Reference, "lib", "src", "alBnkfNew.c"),
	...["host", "mixer", "synthesis_hle"].map((Name) => path.join(Native, `${Name}.c`)),
	...Module,
	"-sEXPORT_NAME=SoundEngine",
	"-sEXPORTED_FUNCTIONS=_audio_buffer,_audio_start,_audio_render_sfx,_audio_render_music,_audio_pcm,_audio_info",
	"-o",
	path.join(Output, "engine.js"),
]);

Emscripten([
	path.join(Native, "vorbis.c"),
	"-w",
	"-sUSE_OGG=1",
	"-sUSE_VORBIS=1",
	...Module,
	"-sEXPORT_NAME=VorbisEncoder",
	"-sEXPORTED_FUNCTIONS=_vorbis_input,_vorbis_encode,_vorbis_output",
	"-o",
	path.join(Output, "vorbis.js"),
]);

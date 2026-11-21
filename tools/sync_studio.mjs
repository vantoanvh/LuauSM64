// Copies the Luau of the project into the folders Studio's built-in sync mirrors: node tools/sync_studio.mjs [--dry] [studio folder]
// --dry only lists what would be written and removed.
//   SM64/        the module tree of ReplicatedStorage.SM64 (port, render, roblox/src) and the client entry SM64MeshClient.client.luau
//   SM64Server/  the server scripts of roblox/scripts (the save slots), to sync with ServerScriptService
// Only changed files are written, and a Luau file the project no longer has is removed from the folders (other files are left alone).
// The client entry requires the modules by paths relative to the SM64 folder, which is the layout of the project, so it is copied as it is.
// A server script runs outside ReplicatedStorage.SM64 and requires its modules by absolute path (rewritten here).

import { existsSync, mkdirSync, readFileSync, readdirSync, rmdirSync, rmSync, statSync, writeFileSync } from "node:fs";
import { dirname, join, posix, relative, sep } from "node:path";
import { fileURLToPath } from "node:url";

const Root = join(dirname(fileURLToPath(import.meta.url)), "..");
const Arguments = process.argv.slice(2);
const Dry = Arguments.includes("--dry");
const ModuleFolder = join(Root, Arguments.find((Argument) => Argument !== "--dry") ?? "SM64");
const ServerFolder = join(Root, "SM64Server");

// The folders mirrored into the module tree and the files left out (they need lute or write files)
const Folders = ["port", "render", "roblox/src"];
const ClientEntry = "SM64MeshClient.client.luau";
const ServerScripts = "roblox/scripts";
const Excluded = new Set(["render/run.luau", "render/png.luau"]);
const Skipped = /^render\/(out\/|run|probe|.*tmp)/;

function Walk(Directory, Files) {
	for (const Name of readdirSync(Directory)) {
		const Path = join(Directory, Name);

		if (statSync(Path).isDirectory()) {
			Walk(Path, Files);
		} else if (Name.endsWith(".luau")) {
			Files.push(relative(Root, Path).split(sep).join("/"));
		}
	}
}

// `require("../x/y")` of a server script becomes the absolute path of the module in ReplicatedStorage.SM64
function RewriteServer(Path, Source, Known) {
	return Source.replace(/require\("(\.\.?\/[^"]*)"\)/g, (Match, Relative) => {
		const Target = posix.normalize(posix.join(posix.dirname(Path), Relative));

		if (!Known.has(`${Target}.luau`)) {
			throw new Error(`${Path}: require("${Relative}") has no module ${Target}.luau`);
		}

		return `require("@game/ReplicatedStorage/SM64/${Target}")`;
	});
}

// The wanted files of a folder: relative path -> contents
const Modules = new Map();
const Servers = new Map();
const Files = [];

for (const Folder of Folders) {
	Walk(join(Root, Folder), Files);
}

const Kept = Files.filter((File) => !Excluded.has(File) && !Skipped.test(File)).sort();
const Known = new Set(Kept);

for (const File of Kept) {
	Modules.set(File, readFileSync(join(Root, File), "utf8"));
}

Modules.set(ClientEntry, readFileSync(join(Root, ClientEntry), "utf8"));

const ServerFiles = [];

Walk(join(Root, ServerScripts), ServerFiles);

for (const File of ServerFiles) {
	if (File.endsWith(".server.luau")) {
		Servers.set(posix.basename(File), RewriteServer(File, readFileSync(join(Root, File), "utf8"), Known));
	}
}

// Writes the changed files of a folder and removes its Luau files that are not wanted any more
function Mirror(Folder, Wanted) {
	let Written = 0;
	let Unchanged = 0;
	let Removed = 0;

	for (const [Path, Source] of Wanted) {
		const Target = join(Folder, Path);

		if (existsSync(Target) && readFileSync(Target, "utf8") === Source) {
			Unchanged++;

			continue;
		}

		if (Dry) {
			console.log(`write ${relative(Root, Target)}`);
		} else {
			mkdirSync(dirname(Target), { recursive: true });
			writeFileSync(Target, Source);
		}

		Written++;
	}

	if (existsSync(Folder)) {
		const Present = [];

		Walk(Folder, Present);

		for (const Path of Present) {
			const Inside = relative(Folder, join(Root, Path)).split(sep).join("/");

			if (!Wanted.has(Inside)) {
				if (Dry) {
					console.log(`remove ${Path}`);
				} else {
					rmSync(join(Root, Path));
				}

				Removed++;
			}
		}

		// directories left empty
		const Empty = (Directory) => {
			for (const Name of readdirSync(Directory)) {
				const Path = join(Directory, Name);

				if (statSync(Path).isDirectory()) {
					Empty(Path);
				}
			}

			if (Directory !== Folder && readdirSync(Directory).length === 0) {
				rmdirSync(Directory);
			}
		};

		if (!Dry) {
			Empty(Folder);
		}
	}

	return `${relative(Root, Folder)}: ${Written} written, ${Unchanged} unchanged, ${Removed} removed`;
}

console.log(Mirror(ModuleFolder, Modules));
console.log(Mirror(ServerFolder, Servers));

--!strict
--!optimize 2

--[[
	Folds the scratch declarations of a module into the fields of one table (`scratch-fields-table`).

	Usage: lute run native/tools/scratch_table.luau <module.luau> <module key> [<bodies file> ...]

	A main chunk holds at most 200 locals, and every `const <function>_<local> = ...` of a `<key>:scratch` block is one. The script
	collects the single line declarations behind a `-- from <key>:scratch` marker of the module (and the ones of the `=== <key>:scratch`
	blocks of the bodies files), writes them as the fields of `const Scratch = { ... }` at the first marker, and rewrites every use
	of those names in the module and in the bodies files to `Scratch.<name>`. A bodies file loses its scratch blocks. Run it again after
	a `submit` that added declarations: the fields of the table are kept. A declaration with a type annotation
	(`const name: T = value`) becomes the field `name = value :: T`.
]]

const Fs = require("@std/fs")
const Process = require("@std/process")

type Field = {
	Name: string,
	Value: string,
}

const function Fail(Message: string): never
	error(Message, 0)
end

-- `const name: Type = value` or `const name = value`
const function ParseDeclaration(Line: string): Field?
	const Name, Rest = string.match(Line, "^const ([%w_]+)(.*)$")

	if Name == nil or Rest == nil then
		return nil
	end

	const Type, Value = string.match(Rest, "^: (.-) = (.*)$")

	if Type ~= nil and Value ~= nil then
		return { Name = Name, Value = `{Value} :: {Type}` }
	end

	const Plain = string.match(Rest, "^ = (.*)$")

	if Plain == nil then
		return Fail(`cannot read the declaration: {Line}`)
	end

	return { Name = Name, Value = Plain }
end

-- `name = value,`: the field of an existing table
const function ParseField(Line: string): Field
	const Name, Value = string.match(Line, "^\t([%w_]+) = (.*),$")

	if Name == nil or Value == nil then
		return Fail(`cannot read the field: {Line}`)
	end

	return { Name = Name, Value = Value }
end

const function AddField(Fields: { Field }, Seen: { [string]: Field }, Entry: Field)
	const Old = Seen[Entry.Name]

	if Old ~= nil then
		if Old.Value ~= Entry.Value then
			Fail(`{Entry.Name} is declared twice with different values`)
		end

		return
	end

	Seen[Entry.Name] = Entry
	table.insert(Fields, Entry)
end

-- every use of a name that is not a field access: `name` becomes `Scratch.name`
const function Rewrite(Text: string, Names: { [string]: boolean }): string
	const Parts: { string } = {}
	local Cursor = 1

	while true do
		const First, Last = string.find(Text, "[%a_][%w_]*", Cursor)

		if First == nil or Last == nil then
			break
		end

		table.insert(Parts, string.sub(Text, Cursor, First - 1))

		const Word = string.sub(Text, First, Last)

		if Names[Word] == true and string.sub(Text, First - 1, First - 1) ~= "." then
			table.insert(Parts, `Scratch.{Word}`)
		else
			table.insert(Parts, Word)
		end

		Cursor = Last + 1
	end

	table.insert(Parts, string.sub(Text, Cursor))

	return table.concat(Parts)
end

const Arguments = Process.args
const ModulePath = Arguments[2]
const Key = Arguments[3]

if ModulePath == nil or Key == nil then
	Fail("usage: scratch_table.luau <module.luau> <module key> [<bodies file> ...]")
end

const Marker = `-- from {Key}:scratch`
const BlockKey = string.gsub(Key, "%.luau$", "")
const Fields: { Field } = {}
const Seen: { [string]: Field } = {}
const ModuleSource = string.split(Fs.readFileToString(ModulePath), "\n")
const Kept: { string } = {}
local Table = 0

-- the module: markers with a declaration or the table are removed, the table goes to the first marker
local Index = 1

while Index <= #ModuleSource do
	const Line = ModuleSource[Index]

	if Line ~= Marker then
		table.insert(Kept, Line)
		Index += 1
		continue
	end

	if Table == 0 then
		Table = #Kept + 1
		table.insert(Kept, Marker)
	end

	Index += 1

	if string.sub(ModuleSource[Index], 1, 15) == "const Scratch =" then
		Index += 1

		while ModuleSource[Index] ~= "}" do
			AddField(Fields, Seen, ParseField(ModuleSource[Index]))
			Index += 1
		end

		Index += 1
	else
		const Entry = ParseDeclaration(ModuleSource[Index])

		if Entry == nil then
			Fail(`line {Index}: a declaration is expected behind the marker`)
		else
			AddField(Fields, Seen, Entry)
			Index += 1
		end
	end
end

if Table == 0 then
	Fail(`no {Marker} in {ModulePath}`)
end

-- the bodies files: the scratch blocks are read and removed
const Bodies: { [string]: { string } } = {}

for Position = 4, #Arguments do
	const Path = Arguments[Position]
	const BodyKept: { string } = {}
	local InScratch = false

	for _, Line in string.split(Fs.readFileToString(Path), "\n") do
		const Header = string.match(Line, "^=== (.-)%s*$")

		if Header ~= nil then
			InScratch = Header == `{Key}:scratch` or Header == `{BlockKey}:scratch`
		end

		if not InScratch then
			table.insert(BodyKept, Line)
		elseif Header == nil and Line ~= "" then
			const Entry = ParseDeclaration(Line)

			if Entry == nil then
				Fail(`{Path}: a declaration is expected in the scratch block: {Line}`)
			else
				AddField(Fields, Seen, Entry)
			end
		end
	end

	Bodies[Path] = BodyKept
end

const Names: { [string]: boolean } = {}
const TableLines = { "const Scratch = {" }

for _, Entry in Fields do
	Names[Entry.Name] = true
	table.insert(TableLines, `\t{Entry.Name} = {Entry.Value},`)
end

table.insert(TableLines, "}")

const ModuleLines = string.split(Rewrite(table.concat(Kept, "\n"), Names), "\n")

for Position = #TableLines, 1, -1 do
	table.insert(ModuleLines, Table + 1, TableLines[Position])
end

Fs.writeStringToFile(ModulePath, table.concat(ModuleLines, "\n"))

for Path, BodyLines in Bodies do
	Fs.writeStringToFile(Path, Rewrite(table.concat(BodyLines, "\n"), Names))
end

print(`{#Fields} scratch fields`)

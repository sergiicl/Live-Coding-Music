local scriptPath = debug.getinfo(1, "S").source:sub(2)
local scriptDirectory = scriptPath:match("^(.*[\\/])")

package.path = scriptDirectory .. "?.lua;" .. package.path

local Lexer = require("lexer")
local Parser = require("parser")
local Patterns = require("music")
local MIDI = require("midi")

local code = "p1 = N(c4, -, [e4, g4], f4)"

local tokens = Lexer.tokenize(code)

local ast = Parser.parse(tokens)

local pattern = Patterns.interpret(ast)

MIDI.play(pattern)
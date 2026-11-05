-- Obtiene la ruta absoluta de este script para poder cargar los módulos
local scriptPath = debug.getinfo(1, "S").source:sub(2)
local scriptDirectory = scriptPath:match("^(.*[\\/])")

-- Añade la carpeta del script a la ruta de búsqueda de módulos de Lua.
package.path = scriptDirectory .. "?.lua;" .. package.path

-- lexer: convierte texto en tokens.
-- parser: convierte tokens en un árbol sintáctico (AST).
-- music: convierte el AST en eventos musicales utilizables.
-- midi: escribe esos eventos en el editor MIDI de REAPER.
local Lexer = require("lexer")
local Parser = require("parser")
local Patterns = require("music")
local MIDI = require("midi")

-- Código que se va a interpretar.
local file = io.open(scriptDirectory .. "melodias.txt", "r")

if not file then
    error("No se ha encontrado melodias.txt")
end

local code = file:read("*a")
file:close()

-- Primera fase: análisis léxico.
-- Cada elemento del resultado identifica una pieza del lenguaje.
local tokens = Lexer.tokenize(code)

-- Segunda fase: análisis sintáctico.
-- Comprueba que los tokens siguen la gramática y crea el AST.
local ast = Parser.parse(tokens)

-- Tercera fase: compilación musical.
-- Convierte los nombres de nota en números MIDI y calcula las posiciones
-- relativas de los eventos.
local compiledPatterns = {}

for _, assignment in ipairs(ast) do
    local pattern = Patterns.compile(assignment)
    table.insert(compiledPatterns, pattern)
end

-- Cuarta fase: integración con REAPER.
-- Busca el take MIDI activo e inserta el patrón desde el beat indicado.
local take = MIDI.getActiveTake()
-- Insertar todos los patrones simultaneamente
reaper.Undo_BeginBlock()

for _, pattern in ipairs(compiledPatterns) do
    MIDI.insertPattern(take, pattern, 0)
end


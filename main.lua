-- Obtiene la ruta absoluta de este script para poder cargar los modulos
local scriptPath = debug.getinfo(1, "S").source:sub(2)
local scriptDirectory = scriptPath:match("^(.*[\\/])")

-- Anade la carpeta del script a la ruta de busqueda de modulos de Lua.
package.path = scriptDirectory .. "?.lua;" .. package.path

-- live: motor en vivo. Usa lexer, parser y music para compilar el codigo
-- y timeline para escribir en Reaper.
local Live = require("live")

Live.start(scriptDirectory .. "melodias.txt")
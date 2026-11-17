-- Obtiene la ruta absoluta de este script para poder cargar los modulos
local scriptPath = debug.getinfo(1, "S").source:sub(2)
local scriptDirectory = scriptPath:match("^(.*[\\/])")

-- Agrega la carpeta del script a la ruta de busqueda de modulos de Lua.
package.path = scriptDirectory .. "?.lua;" .. package.path

-- live: Es el motor en vivo. 
-- Command_Parser: Es el encargado de parsear los comandos
-- timeline: Es el encargado de escribir en Reaper

local Live = require("Tracks.live")

Live.start(scriptDirectory .. "melodias.txt")
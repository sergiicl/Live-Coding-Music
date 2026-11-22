-- Obtiene la ruta absoluta de este script para poder cargar los modulos
local scriptPath = debug.getinfo(1, "S").source:sub(2)
local scriptDirectory = scriptPath:match("^(.*[\\/])")

-- Agrega la carpeta del script a la ruta de busqueda de modulos de Lua.
package.path = scriptDirectory .. "?.lua;" .. package.path

local GUI = require('gui.example-gui-rtk')
GUI.initGUI()
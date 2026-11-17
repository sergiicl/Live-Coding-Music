-- Importar librerías necesarias
local lpeg = require("Parsing.lulpeg")

-- Funciones de la librería LPeg
local P, R, S, V = lpeg.P, lpeg.R, lpeg.S, lpeg.V
local C, Ct, Cg = lpeg.C, lpeg.Ct, lpeg.Cg

---------------------------------------
----------- ANALISIS LEXICO -----------
---------------------------------------

-- Cadenas ignorables
local escape = S(" \t\n\r\b")
local comment = P("--") * (1 - P("\n"))^0 * (P("\n") + -1)

local ignore = (escape + comment)^0

-- Función auxiliar para consumir las cadenas ignorables en cada token
local function token(p)
    return p * ignore
end

-- Clases léxicas unievaluadas (palabras reservadas)
local n_kw   = token(P("N"))
local dur_kw = token(P("dur"))

-- Clases léxicas unievaluadas (símbolos)
local assign     = token(P("="))
local punto      = token(P("."))
local coma       = token(P(","))
local par_a      = token(P("("))
local par_c      = token(P(")"))
local cor_a      = token(P("["))
local cor_c      = token(P("]"))
local guion      = token(C(P("-")))
local barra_baja = token(P("_"))
local sostenido  = token(P("#"))
local bemol      = token(P('b'))

-- Definiciones auxiliares
local letra      = R("az", "AZ")
local digito     = R("09")
local digito_pos = R("19")
local p_decimal  = (P("0")^0 * digito_pos)^1 + P("0")

-- Clases léxicas multievaluadas
local p_ent    = (digito_pos * digito^0) + P("0")
local p_float  = p_ent * punto * p_decimal
local p_nombre = C(letra * (letra + barra_baja + digito)^0)
local p_nota   = C(((S("adg") * (bemol + sostenido)^-1) +
                    (S("be") * bemol^-1) +
                    (S("cf") * sostenido^-1)) *
                    (digito + P("-1"))^-1)

local ent    = token(C(p_ent) / tonumber)
local float  = token(C(p_float) / tonumber)
local nombre = token(p_nombre)
local nota   = token(p_nota)

---------------------------------------
--------- ANALISIS SINTACTICO ---------
---------------------------------------

local G = lpeg.P({
    "ASIGNACION", -- Producción inicial

    -- ASIGNACION → nombre = N(ARGS)ATRIBUTOS
    ASIGNACION = Ct(
                    Cg(nombre, "name") * assign * n_kw * par_a *
                    Cg(V("ARGS"), "notes") * par_c *
                    Cg(V("ATRIBUTOS"), "attributes")
                 ),

    -- ARGS → ARG | ARG, ARGS
    -- ARG → nota | CHORD | guion
    ARGS = Ct((nota + (cor_a * V("LISTA_NOTAS") * cor_c) + guion) *
              (coma * (nota + (cor_a * V("LISTA_NOTAS") * cor_c) + guion))^0),

    -- LISTA_NOTAS → nota | nota, LISTA_NOTAS
    LISTA_NOTAS = Ct(nota * (coma * nota)^0),

    -- ATRIBUTOS → ϵ | LISTA_ATTR 
    ATRIBUTOS = Ct(V("ATTR")^0),

    -- ATTR → .dur(LISTA_NUM) 
    ATTR = punto * ((dur_kw * par_a * Cg(V("LISTA_NUM"), "dur") * par_c)),

    -- LISTA_NUM → ent | float | ent, LISTA_NUM | float, LISTA_NUM
    LISTA_NUM = Ct((float + ent) * (coma * (float + ent))^0)
})

local Command_Parser = { parser = ignore * G * P(-1) }

function Command_Parser.parse_cmd(cmd)
    return Command_Parser.parser:match(cmd)
end

return Command_Parser
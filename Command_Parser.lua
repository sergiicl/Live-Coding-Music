local lpeg = require "lpeg"
local inspect = require("inspect")
local P, R, S, V = lpeg.P, lpeg.R, lpeg.S, lpeg.V
local C, Ct, Cg = lpeg.C, lpeg.Ct, lpeg.Cg

---------------------------------------
----------- ANALISIS LEXICO -----------
---------------------------------------

-- Cadenas ignorables
local space = S(" \t\n\r\b")^0

-- Función auxiliar para consumir espacios después de cada token
local function tok(p)
    return p * space
end

-- Definiciones auxiliares
local letra = R("az", "AZ")
local digito = R("09")
local digito_pos = R("19")
local p_decimal = (digito^0 * digito_pos) + P("0")

-- Clases léxicas multievaluadas
local p_ent = C((digito_pos * digito^0) + P("0")) / tonumber
local p_float = C(p_ent * P(".") * p_decimal) / tonumber
local p_nombre = C(letra * (letra + P("_") + digito)^0)
local p_nota = C(((S("acdfg") * P("#")^-1) + P("b") + P("e")) * digito^-1)

local ent_tok = tok(p_ent)
local float_tok = tok(p_float)
local nombre_tok = tok(p_nombre)
local nota_tok = tok(p_nota)

-- Clases léxicas unievaluadas (palabras reservadas)
local n_kw_tok = tok(P("N"))
local dur_kw_tok = tok(P("dur"))

-- Clases léxicas unievaluadas (símbolos)
local assign_tok = tok(P("="))
local punto_tok = tok(P("."))
local coma_tok = tok(P(","))
local para_tok = tok(P("("))
local parc_tok = tok(P(")"))
local cora_tok = tok(P("["))
local corc_tok = tok(P("]"))
local guion_tok = tok(C(P("-")))

---------------------------------------
--------- ANALISIS SINTACTICO ---------
---------------------------------------

local G = lpeg.P({
    "ASIGNACION",

    -- ASIGNACION → nombre = N(ARGS)ATRIBUTOS
    ASIGNACION = Ct(
                    Cg(nombre_tok, "name") * assign_tok * n_kw_tok * para_tok *
                    Cg(V("ARGS"), "notes") * parc_tok *
                    Cg(V("ATRIBUTOS"), "attributes")
                ),

    -- ARGS → ARG | ARG, ARGS
    ARGS = Ct((nota_tok + (cora_tok * V("LISTA_NOTAS") * corc_tok) + guion_tok) *
               (coma_tok * (nota_tok + (cora_tok * V("LISTA_NOTAS") * corc_tok) + guion_tok))^0),

    -- ARG → nota | CHORD | guion
    ARG = Ct(nota_tok + V("CHORD") + guion_tok),

    -- CHORD → [LISTA_NOTAS]
    CHORD = Ct(cora_tok * V("LISTA_NOTAS") * corc_tok),

    -- LISTA_NOTAS → nota | nota, LISTA_NOTAS
    LISTA_NOTAS = Ct(nota_tok * (coma_tok * nota_tok)^0),

    -- ATRIBUTOS → ϵ | LISTA_ATTR 
    ATRIBUTOS = Ct(V("ATTR")^0),

    -- ATTR → .dur(LISTA_NUM) 
    ATTR = punto_tok * (
            (dur_kw_tok * para_tok * Cg(V("LISTA_NUM"), "dur") * parc_tok)
        ),

    -- LISTA_NUM → ent | float | ent, LISTA_NUM | float, LISTA_NUM
    LISTA_NUM = Ct((float_tok + ent_tok) * (coma_tok * (float_tok + ent_tok))^0)
})

local parser = space * G * P(-1)

local cadena_ejemplo = "p1 = N(c4, -, e4, -, g4, -, e4, -, [c5, d6]).dur(5, 6)"
local ast = parser:match(cadena_ejemplo)
if ast then
    print(inspect(ast))
else
    print("Cadena sintácticamente incorrecta")
end

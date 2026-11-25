-- Parser y lexer

-- Importar librerías necesarias
local lpeg = require("Libs.lulpeg")

-- Funciones de la librería LPeg
local P, R, S, V = lpeg.P, lpeg.R, lpeg.S, lpeg.V
local C, Ct, Cg = lpeg.C, lpeg.Ct, lpeg.Cg

---------------------------------------
----------- ANALISIS LEXICO -----------
---------------------------------------

-- Cadenas ignorables
local escape = S(" \t\n\r\b")
local comment = P("--") * (1 - P("\n")) ^ 0 * (P("\n") + -1)

local ignore = (escape + comment) ^ 0

-- Función auxiliar para consumir las cadenas ignorables en cada token
local function token(p)
    return p * ignore
end

-- Definiciones auxiliares
local letra = R("az", "AZ")
local digito = R("09")
local digito_pos = R("19")
local p_decimal = (P("0") ^ 0 * digito_pos) ^ 1 + P("0")

-- Clases léxicas unievaluadas (palabras reservadas)
local n_kw = token(P("N"))
local prog_kw = token(P("P"))
local dur_kw = token(P("dur"))
local key_kw = token(P("key"))
local mode_kw = token(P("mode"))
local scale_kw = token(P("scale"))

-- Sufijos válidos para grados romanos
local cualidad_romano =
    P("minmaj7") + P("maj7#5") + P("maj7") + P("m7b5") + P("min7b5") + P("dim7") + P("dim") + P("aug") + P("m") +
    P("+M") +
    P("+") +
    P("o") +
    P("0") +
    P("h") +
    P("M")

local extension_romano = P("6-9") + P("13") + P("11") + P("9") + P("7") + P("6")
local inversion_romano = S("bcdefg")

-- Grados romanos (tríadas, extensiones, 6-9 e inversiones)
local p_romano =
    C(
    (P("VII") + P("VI") + P("IV") + P("V") + P("III") + P("II") + P("I") + P("vii") + P("vi") + P("iv") + P("v") +
        P("iii") +
        P("ii") +
        P("i")) *
        cualidad_romano ^ -1 *
        extension_romano ^ -1 *
        inversion_romano ^ -1
)
local romano = token(p_romano)
local modo = token(C(P("major") + P("minor")))

-- Clases léxicas unievaluadas (símbolos)
local assign = token(P("="))
local punto = token(P("."))
local coma = token(P(","))
local par_a = token(P("("))
local par_c = token(P(")"))
local cor_a = token(P("["))
local cor_c = token(P("]"))
local guion = token(C(P("-")))
local barra_baja = token(P("_"))
local sostenido = token(P("#"))
local bemol = token(P("b"))

-- Clases léxicas multievaluadas
local p_ent = (digito_pos * digito ^ 0) + P("0")
local p_float = p_ent * punto * p_decimal
local p_nombre = C(letra * (letra + barra_baja + digito) ^ 0)
local p_nota =
    C(
    ((S("adg") * (bemol + sostenido) ^ -1) + (S("be") * bemol ^ -1) + (S("cf") * sostenido ^ -1)) *
        (digito + P("-1")) ^ -1
)
local p_escala = C((letra + digito) ^ 1 * (S(" _") ^ 1 * (letra + digito) ^ 1) ^ 0)

local ent = token(C(p_ent) / tonumber)
local float = token(C(p_float) / tonumber)
local nombre = token(p_nombre)
local nota = token(p_nota)
local escala = token(p_escala)

---------------------------------------
--------- ANALISIS SINTACTICO ---------
---------------------------------------

local G =
    lpeg.P(
    {
        "ASIGNACION", -- Producción inicial
        -- ASIGNACION → nombre = N(ARGS_NOTAS)ATRIBUTOS | nombre = P(ARGS_PROG)ATRIBUTOS
        ASIGNACION = Ct(
            Cg(nombre, "name") * assign *
                ((n_kw * par_a * Cg(V("ARGS_NOTAS"), "notes") * par_c) +
                    (prog_kw * par_a * Cg(V("ARGS_PROG"), "notes") * par_c)) *
                Cg(V("ATRIBUTOS"), "attributes")
        ),
        -- ARGS_NOTAS → nota, acorde manual [...] o silencio -
        ARGS_NOTAS = Ct(V("EVENTO_NOTA") * (coma * V("EVENTO_NOTA")) ^ 0),
        EVENTO_NOTA = nota + (cor_a * V("LISTA_NOTAS") * cor_c) + guion,
        -- ARGS_PROG → grado romano o silencio -
        ARGS_PROG = Ct(V("EVENTO_PROG") * (coma * V("EVENTO_PROG")) ^ 0),
        EVENTO_PROG = romano + guion,
        -- LISTA_NOTAS → nota | nota, LISTA_NOTAS
        LISTA_NOTAS = Ct(nota * (coma * nota) ^ 0),
        -- ATRIBUTOS → ϵ | LISTA_ATTR
        ATRIBUTOS = Ct(V("ATTR") ^ 0),
        -- ATTR → admite .dur(...), .key(c4), .mode(minor) y .scale(Dorian)
        ATTR = punto *
            ((dur_kw * par_a * Cg(V("LISTA_NUM"), "dur") * par_c) + (key_kw * par_a * Cg(nota, "key") * par_c) +
                (mode_kw * par_a * Cg(modo, "mode") * par_c) +
                (scale_kw * par_a * Cg(escala, "scale") * par_c)),
        -- LISTA_NUM → ent | float | ent, LISTA_NUM | float, LISTA_NUM
        LISTA_NUM = Ct((float + ent) * (coma * (float + ent)) ^ 0)
    }
)

local Command_Parser = {parser = ignore * G * P(-1)}

function Command_Parser.parse_cmd(cmd)
    return Command_Parser.parser:match(cmd)
end

return Command_Parser

-- Crea el midi
-- Compatibilidad para que musicutil.lua funcione dentro de REAPER
util = util or {}
util.clamp = util.clamp or function(n, min, max) return math.min(max, math.max(min, n)) end
util.round = util.round or function(n) return math.floor(n + 0.5) end

local MusicUtil = require("Libs.musicutil")

NOTES_INDEX = {['c'] = 0, ['d'] = 2, ['e'] = 4, ['f'] = 5, ['g'] = 7, ['a'] = 9, ['b'] = 11}

DEFAULT_OCT = 4 -- La octava que se usa por defecto en caso de que no venga junto a la nota
MAX_MIDI = 127 -- El máximo valor que puede adquirir una nota en formato MIDI

Music = {}

-- Convierte una nota en texto (ej. "c4", "f#3") a número MIDI
local function note_to_midi(n)
    local note = n:sub(1, 1)
    local semitone = n:sub(2, 2)
    local oct = tonumber(n:sub(#n - 1)) or tonumber(n:sub(#n)) or DEFAULT_OCT

    return ((semitone == "#" and NOTES_INDEX[note] + 1) or
            (semitone == "b" and NOTES_INDEX[note] - 1) or
             NOTES_INDEX[note]) + 12 * (oct + 1)
end

-- Comprueba si el nombre de la escala existe en MusicUtil.SCALES (name o alt_names, case-insensitive)
local function scale_exists(scale_name)
    local target = string.lower(scale_name)
    for _, scale in ipairs(MusicUtil.SCALES) do
        if string.lower(scale.name) == target then
            return true
        end
        if scale.alt_names then
            for _, alt in ipairs(scale.alt_names) do
                if string.lower(alt) == target then
                    return true
                end
            end
        end
    end
    return false
end

-- Comprueba si el token es un número romano (con o sin extensiones/inversiones)
local function is_roman_chord(str)
    return str:match("^[ivxIVX]+") ~= nil
end

-- Traduce alias cómodos a la sintaxis exacta que espera MusicUtil.generate_chord_roman
local function normalize_roman_chord(str)
    local numeral, rest = str:match("^([ivxIVX]+)(.*)$")
    if not numeral or rest == "" then return str end

    rest = rest:gsub("^minmaj7", "h7")
    rest = rest:gsub("^maj7#5", "+M7")
    rest = rest:gsub("^maj7", "M7")
    rest = rest:gsub("^m7b5", "07")
    rest = rest:gsub("^min7b5", "07")
    rest = rest:gsub("^dim7", "o7")
    rest = rest:gsub("^dim", "o")
    rest = rest:gsub("^aug", "+")
    rest = rest:gsub("^m([679])", "%1")
    rest = rest:gsub("^m(1[13])", "%1")

    return numeral .. rest
end

-- Recibe una lista de notas en forma de strings y la parsea con su dígito correspondiente en formato MIDI
function Music.parse_notes(notes, key_str, mode_str, scale_str)
    local num_notes = {}
    local tonic = key_str and note_to_midi(key_str) or 60
    local raw_scale = scale_str or mode_str or "Major"
    local scale_type = raw_scale:gsub("_", " ")

    -- VALIDACIÓN SEMÁNTICA: la escala debe existir en MusicUtil.SCALES
    if not scale_exists(scale_type) then
        error("Escala no reconocida: '" .. scale_type .. "'")
    end

    for _, n in ipairs(notes) do
        if type(n) == "table" then -- Es un acorde manual [...]
            table.insert(num_notes, Music.parse_notes(n, key_str, mode_str, scale_str))
        elseif is_roman_chord(n) then -- Acorde en numeración romana
            local normalized = normalize_roman_chord(n)
            local chord_midi = MusicUtil.generate_chord_roman(tonic, scale_type, normalized)
            if not chord_midi then
                error("Acorde romano no valido: '" .. n .. "' en escala '" .. scale_type .. "'")
            end
            table.insert(num_notes, chord_midi)
        elseif n == "-" then -- Silencio
            table.insert(num_notes, -1)
        else -- Nota individual
            local midi = note_to_midi(n)
            table.insert(num_notes, midi > MAX_MIDI and -1 or midi)
        end
    end

    return num_notes
end

return Music
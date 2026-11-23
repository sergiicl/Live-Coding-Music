-- Crea el midi
-- Compatibilidad para que musicutil.lua funcione dentro de REAPER
util = util or {}
util.clamp = util.clamp or function(n, min, max) return math.min(max, math.max(min, n)) end

local MusicUtil = require("Tracks.musicutil")

NOTES_INDEX = {['c'] = 0, ['d'] = 2,  ['e'] = 4, ['f'] = 5, ['g'] = 7, ['a'] = 9, ['b'] = 11}

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


-- Comprueba si el token es un número romano (tríada)
local function is_roman_chord(str)
    return str:match("^[ivIV]+[o+]?$") ~= nil
end

-- Recibe una lista de notas en forma de strings y la parsea con su dígito correspondiente en formato MIDI
function Music.parse_notes(notes, key_str, mode_str)
    local num_notes = {}
    local tonic = key_str and note_to_midi(key_str) or 60
     local scale_type = (mode_str == "minor") and "Natural Minor" or "Major"

    for _, n in ipairs(notes) do

        if type(n) == "table" then -- Es un acorde
            table.insert(num_notes, Music.parse_notes(n, key_str, mode_str))
         elseif is_roman_chord(n) then -- Tríada en numeración romana (I, ii, V, viio...)
            local chord_midi = MusicUtil.generate_chord_roman(tonic, scale_type, n)
            table.insert(num_notes, chord_midi or -1)
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

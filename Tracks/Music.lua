NOTES_INDEX = {['c'] = 0, ['d'] = 2,  ['e'] = 4, ['f'] = 5, ['g'] = 7, ['a'] = 9, ['b'] = 11}

DEFAULT_OCT = 4 -- La octava que se usa por defecto en caso de que no venga junto a la nota
MAX_MIDI = 127 -- El máximo valor que puede adquirir una nota en formato MIDI

Music = {}

-- Recibe una lista de notas en forma de strings y la parsea con su dígito correspondiente en formato MIDI
function Music.parse_notes(notes)
    local num_notes = {}

    for _, n in ipairs(notes) do

        if type(n) == "table" then -- Es un acorde
            table.insert(num_notes, Music.parse_notes(n))
        else -- Es una nota o un silencio
            local note = n:sub(1, 1)
            local semitone = n:sub(2, 2)
            local oct = tonumber(n:sub(#n - 1)) or tonumber(n:sub(#n)) or DEFAULT_OCT

            if note == "-" then -- Es un silencio
                table.insert(num_notes, -1)
            else -- Es una nota
                note = ((semitone == "#" and NOTES_INDEX[note] + 1) or
                        (semitone == "b" and NOTES_INDEX[note] - 1) or
                         NOTES_INDEX[note]) + 12 * (oct + 1)
                -- Si la nota es mayor o igual a 128 se cuenta como un silencio
                table.insert(num_notes, note > MAX_MIDI and -1 or note)
            end
        end
    end

    return num_notes
end

return Music

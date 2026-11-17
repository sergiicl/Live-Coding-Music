local Music = require("Tracks.Music")

local TrackManager = { tracks = {} }

function TrackManager.parse_ast(ast)
    -- Si no viene especificada la duración se usa por defecto el valor de 1 para todas las notas (una negra)
    local dur = ast.attributes["dur"] or { 1 }
    local notes = Music.parse_notes(ast.notes)

    local events = {}
    local currentBeat = 0

    for i, note in ipairs(notes) do
        local eventDur = dur[((i - 1) % #dur) + 1]
        local event = { startBeat = currentBeat, duration = eventDur }

        if type(note) == "table" then -- Es un acorde
            event.type = "chord"
            event.notes = {}

            for _, chord_note in ipairs(note) do
                table.insert(event.notes, chord_note)
            end
        else
            if note == -1 then -- Es un silencio
                event.type = "rest"
            else -- Es una nota
                event.type = "note"
                event.notes = { note }
            end
        end

        table.insert(events, event)
        currentBeat = currentBeat + eventDur
    end

    return { name = ast.name, events = events, totalBeats = currentBeat }
end

return TrackManager
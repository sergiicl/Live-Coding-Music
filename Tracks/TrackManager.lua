-- Parsea el AST: identifica si es una nota, rest etc

local Music = require("Tracks.Music")

local TrackManager = { tracks = {} }

function TrackManager.parse_ast(ast)
    -- Si no viene especificada la duración se usa por defecto el valor de 1 para todas las notas (una negra)
    local dur = ast.attributes["dur"] or { 1 }

    -- VALIDACIÓN SEMÁNTICA: solo se permiten múltiplos positivos de 0.25
    for _, d in ipairs(dur) do
        if d <= 0 or (d % 0.25) ~= 0 then
            error("Duracion no valida (" .. d .. "): debe ser un multiplo positivo de 0.25 (ej. 0.25, 0.5, 0.75, 1, 2)")
        end
    end

    local key   = ast.attributes["key"]
    local mode  = ast.attributes["mode"]
    local scale = ast.attributes["scale"]
    local notes = Music.parse_notes(ast.notes, key, mode, scale)

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
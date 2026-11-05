
local Music = {}

-- Número de semitonos que corresponde a cada nota dentro de una octava.
-- La octava completa se calcula después usando la fórmula MIDI estándar.
local noteValues = {
    c = 0,
    d = 2,
    e = 4,
    f = 5,
    g = 7,
    a = 9,
    b = 11
}

function Music.noteToMIDI(note)
    -- El lexer ya valida la forma general de la nota, pero esta función
    -- también se protege porque forma parte de la API pública del módulo.
    local name = note:sub(1, 1)
    local octave = tonumber(note:sub(2))

    if not noteValues[name] or not octave then
        error("Nota no valida: " .. note)
    end

    -- En MIDI, C-1 es 0 y cada octava contiene 12 semitonos.
    local midiNote = 12 * (octave + 1) + noteValues[name]

    -- MIDI solo puede representar los valores enteros de 0 a 127.
    if midiNote < 0 or midiNote > 127 then
        error("Nota fuera del rango MIDI: " .. note)
    end

    return midiNote
end

function Music.compile(ast)
    -- La compilación recibe el AST y genera una representación intermedia
    -- independiente de REAPER.
    if ast.type ~= "assignment" then
        error("Se esperaba una asignacion")
    end

    local pattern = ast.pattern
    local events = {}
    local currentBeat = 0

    -- Cada evento ocupa la duración del patrón; por eso el siguiente evento
    -- comienza justo cuando termina el anterior.
    for _, event in ipairs(pattern.events) do
        local compiledEvent = {
            type = event.type,
            startBeat = currentBeat,
            duration = pattern.duration
        }

        if event.type == "note" then
            -- Una nota individual se representa como una lista de un pitch.
            compiledEvent.notes = {
                Music.noteToMIDI(event.value)
            }

        elseif event.type == "chord" then
            -- Un acorde contiene varios pitches que comparten posición
            -- temporal y duración.
            compiledEvent.notes = {}

            for _, note in ipairs(event.notes) do
                table.insert(
                    compiledEvent.notes,
                    Music.noteToMIDI(note.value)
                )
            end

        elseif event.type ~= "rest" then
            -- Esta comprobación protege la frontera entre el parser y el
            -- compilador si en el futuro se añaden nuevos nodos al AST.
            error("Tipo de evento desconocido: " .. event.type)
        end

        table.insert(events, compiledEvent)

        currentBeat = currentBeat + pattern.duration
    end

    -- totalBeats permite a los consumidores conocer la duración completa
    -- sin volver a recorrer todos los eventos.
    return {
        name = ast.name,
        events = events,
        totalBeats = currentBeat
    }
end

return Music

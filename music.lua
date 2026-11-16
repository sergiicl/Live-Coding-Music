
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
   -- Soporta formato "c4" y también sostenidos como "c#4" (o sin octava, usando 4 por defecto).
    local name, sharp, octaveStr = note:match("^([a-g])(#?)(%d*)$")

    if not noteValues[name] or not name then
        error("Nota no valida: " .. note)
    end

    local octave = (octaveStr ~= "") and tonumber(octaveStr) or 4
    local semitoneOffset = (sharp == "#") and 1 or 0

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
    if type(ast) ~= "table" or not ast.name or not ast.notes then
        error("Se esperaba una asignacion")
    end

    -- Extraer la lista de duraciones desde attributes (por defecto { 0.5 }).
    local durations = { 0.5 }

    if ast.attributes then
        for _, attr in ipairs(ast.attributes) do
            if attr.dur and #attr.dur > 0 then
                durations = attr.dur
            end
        end
    end

    for _, d in ipairs(durations) do
        if d <= 0 then
            error("La duracion debe ser mayor que cero")
        end
    end

    local events = {}
    local currentBeat = 0

    -- Cada evento ocupa la duración del patrón; por eso el siguiente evento
    -- comienza justo cuando termina el anterior.
    for i, item in ipairs(ast.notes) do
        local eventDuration = durations[((i - 1) % #durations) + 1]
        local compiledEvent = {
            startBeat = currentBeat,
            duration = pattern.duration
        }

        if item == "-" then
            compiledEvent.type = "rest"

        elseif type(item) == "string" then
            compiledEvent.type = "note"
            compiledEvent.notes = {
                Music.noteToMIDI(item)
            }

        elseif type(item) == "table" then
            compiledEvent.type = "chord"
            compiledEvent.notes = {}

            for _, noteStr in ipairs(item) do
                table.insert(
                    compiledEvent.notes,
                    Music.noteToMIDI(noteStr)
                )
            end

        else
            error("Elemento desconocido en el patron: " .. tostring(item))
        end

        table.insert(events, compiledEvent)

        currentBeat = currentBeat + eventDuration
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

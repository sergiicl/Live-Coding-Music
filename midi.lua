
local Midi = {}

function Midi.getActiveTake()
    -- REAPER expone primero el editor MIDI y después el take que contiene
    -- sus eventos. Ambas referencias pueden no existir.
    local editor = reaper.MIDIEditor_GetActive()

    if not editor then
        error("No hay ningun editor MIDI abierto")
    end

    local take = reaper.MIDIEditor_GetTake(editor)

    if not take then
        error("No se ha encontrado un MIDI take activo")
    end

    return take
end

function Midi.insertPattern(take, pattern, startPPQ, velocity, channel)
    -- Los parámetros opcionales siguen las convenciones de REAPER:
    -- posición inicial 0, velocidad 100 y canal MIDI 0.
    startPPQ = startPPQ or 0
    velocity = velocity or 100
    channel = channel or 0

    -- Convierte beats musicales a posiciones PPQ usando la resolución real
    -- del take, en lugar de asumir una resolución fija.
    local ticksPerBeat =
        reaper.MIDI_GetPPQPosFromProjQN(take, 1) -
        reaper.MIDI_GetPPQPosFromProjQN(take, 0)

    -- Recorre los eventos ya compilados conservando su orden temporal.
    for _, event in ipairs(pattern.events) do
        if event.type ~= "rest" then
            -- Los silencios avanzan el tiempo, pero no generan notas MIDI.
            local startPosition =
                startPPQ + event.startBeat * ticksPerBeat

            local endPosition =
                startPosition + event.duration * ticksPerBeat

            -- Los acordes tienen varias notas con exactamente los mismos
            -- límites temporales.
            for _, pitch in ipairs(event.notes) do
                reaper.MIDI_InsertNote(
                    take,
                    false,
                    false,
                    startPosition,
                    endPosition,
                    channel,
                    pitch,
                    velocity,
                    true
                )
            end
        end
    end

    -- Ordena los eventos para que REAPER mantenga consistente el take MIDI.
    reaper.MIDI_Sort(take)
end

return Midi

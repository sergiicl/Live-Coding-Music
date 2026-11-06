
local Midi = {}

-- Busca una pista del proyecto o crea una nueva.
local function getOrCreateTrack(patternName)
    local trackName = "[LC] " .. patternName
    local trackCount = reaper.CountTracks(0)

    for i = 0, trackCount - 1 do
        local track = reaper.GetTrack(0, i)
        local _, name = reaper.GetSetMediaTrackInfo_String(
            track, "P_NAME", "", false
        )

        if name == trackName then
            return track
        end
    end

    reaper.InsertTrackAtIndex(trackCount, false)

    local track = reaper.GetTrack(0, trackCount)

    reaper.GetSetMediaTrackInfo_String(
        track, "P_NAME", trackName, true
    )

    return track
end

-- Crea un MIDI item y devuelve su take.
local function createMIDIItem(track, totalBeats)
    -- Eliminamos los items anteriores de esta pista.
    -- Las pistas [LC] están reservadas para nuestro programa.
    local itemCount = reaper.CountTrackMediaItems(track)

    for i = itemCount - 1, 0, -1 do
        local item = reaper.GetTrackMediaItem(track, i)
        reaper.DeleteTrackMediaItem(track, item)
    end

    local item = reaper.CreateNewMIDIItemInProj(
        track, 0, math.max(totalBeats, 0.5), true
    )

    if not item then
        error("No se ha podido crear el MIDI item")
    end

    local take = reaper.GetActiveTake(item)

    if not take then
        error("No se ha podido obtener el MIDI take")
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

-- Crea o actualiza la pista correspondiente a un patrón.
function Midi.createTrackForPattern(pattern)
    local track = getOrCreateTrack(pattern.name)

    local take = createMIDIItem(track, pattern.totalBeats)

    Midi.insertPattern(take, pattern, 0)

    return track
end

return Midi

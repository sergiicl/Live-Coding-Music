-- timeline.lua
--
-- Todo lo que toca la API de Reaper para escribir en la timeline:
-- pistas, items y notas, ademas del estado del transporte.
-- No sabe nada de lenguajes, ni de cuando hay que escribir:
-- eso lo decide live.lua.

local Timeline = {}

local VELOCITY = 100
local CHANNEL  = 0


-- ==========================================================
-- TRANSPORTE
-- ==========================================================

function Timeline.isPlaying()
    return (reaper.GetPlayState() & 1) ~= 0
end

-- Posicion de reproduccion actual, en beats (negras).
function Timeline.getPlayPositionQN()
    return reaper.TimeMap2_timeToQN(0, reaper.GetPlayPosition())
end


-- ==========================================================
-- PISTAS: una por patron, identificada por su nombre
-- ==========================================================

local function findTrackByName(name)

    for i = 0, reaper.CountTracks(0) - 1 do

        local track = reaper.GetTrack(0, i)
        local _, trackName = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)

        if trackName == name then
            return track
        end

    end

    return nil

end

-- Devuelve la pista con ese nombre, creandola si no existe.
-- Si se pasa la pista que se tenia guardada y sigue viva, se reutiliza.
function Timeline.getTrack(name, cachedTrack)

    if cachedTrack and reaper.ValidatePtr(cachedTrack, "MediaTrack*") then
        return cachedTrack
    end

    local track = findTrackByName(name)

    if not track then

        local numTracks = reaper.CountTracks(0)
        reaper.InsertTrackAtIndex(numTracks, true)
        track = reaper.GetTrack(0, numTracks)
        reaper.GetSetMediaTrackInfo_String(track, "P_NAME", name, true)

    end

    return track

end


-- ==========================================================
-- ITEMS
-- ==========================================================

-- Escribe las notas de un patron en un take, a partir de startPPQ.
local function insertPattern(take, pattern, startPPQ)

    -- Resolucion real del take, sin asumir una fija.
    local ticksPerBeat =
        reaper.MIDI_GetPPQPosFromProjQN(take, 1) -
        reaper.MIDI_GetPPQPosFromProjQN(take, 0)

    for _, event in ipairs(pattern.events) do

        -- Los silencios avanzan el tiempo pero no generan notas.
        if event.type ~= "rest" then

            local startPosition = startPPQ + event.startBeat * ticksPerBeat
            local endPosition   = startPosition + event.duration * ticksPerBeat

            -- Un acorde son varias notas con los mismos limites.
            for _, pitch in ipairs(event.notes) do

                reaper.MIDI_InsertNote(
                    take, false, false,
                    startPosition, endPosition,
                    CHANNEL, pitch, VELOCITY,
                    true
                )

            end

        end

    end

    reaper.MIDI_Sort(take)

end

-- true si ya hay algun item de la pista ocupando ese rango.
local function rangeHasItem(track, startTime, endTime)

    for i = 0, reaper.CountTrackMediaItems(track) - 1 do

        local item = reaper.GetTrackMediaItem(track, i)
        local pos  = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        local len  = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")

        if pos < endTime - 0.001 and pos + len > startTime + 0.001 then
            return true
        end

    end

    return false

end

-- Crea un item MIDI con el patron, empezando en startQN y con la duracion
-- del patron. Devuelve el item, o nil si ese hueco ya estaba ocupado.
function Timeline.createBlock(track, pattern, startQN)

    local startTime = reaper.TimeMap2_QNToTime(0, startQN)
    local endTime   = reaper.TimeMap2_QNToTime(0, startQN + pattern.totalBeats)

    if rangeHasItem(track, startTime, endTime) then
        return nil
    end

    local item = reaper.CreateNewMIDIItemInProj(track, startTime, endTime, false)

    if not item then
        return nil
    end

    local take = reaper.GetActiveTake(item)

    if not take then
        return nil
    end

    insertPattern(take, pattern, reaper.MIDI_GetPPQPosFromProjQN(take, startQN))

    reaper.UpdateItemInProject(item)
    reaper.UpdateArrange()

    return item

end

-- true si el item guardado sigue existiendo (no lo han borrado a mano).
function Timeline.isItemValid(item)
    return item ~= nil and reaper.ValidatePtr(item, "MediaItem*")
end

function Timeline.deleteItem(item)

    reaper.DeleteTrackMediaItem(reaper.GetMediaItemTrack(item), item)
    reaper.UpdateArrange()

end

return Timeline
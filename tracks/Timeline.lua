Timeline = {}

local CHANNEL = 0
local VELOCITY = 100

function Timeline.isPlaying()
    return (reaper.GetPlayState() & 1) ~= 0
end

function Timeline.getQnPlayPosition()
    return reaper.TimeMap2_timeToQN(0, reaper.GetPlayPosition())
end

function Timeline.insert_track(track)

    reaper.InsertTrackAtIndex(track.index, true)
    local reaper_track = reaper.GetTrack(0, track.index)
    reaper.GetSetMediaTrackInfo_String(reaper_track, "P_NAME", track.name, true)

end

local function are_items_in_range(track, start_time, end_time)
    local i, n = 0, reaper.CountTrackMediaItems(track)
    local no_items = false

    while i < n and not no_items do
        local item = reaper.GetTrackMediaItem(track, i)
        local position  = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        local length  = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")

        no_items = position < end_time - 0.001 and position + length > start_time + 0.001
        i = i + 1
    end

    return no_items
end

local function insert_pattern(take, events, start_ppq)
    local ticks_per_beat = reaper.MIDI_GetPPQPosFromProjQN(take, 1) -
                            reaper.MIDI_GetPPQPosFromProjQN(take, 0)
    for _, event in ipairs(events) do
        if event.type ~= "rest" then
            local start_position = start_ppq + event.start_beat * ticks_per_beat
            local end_position = start_position + event.duration * ticks_per_beat

            for _, pitch in ipairs(event.pitches) do
                reaper.MIDI_InsertNote(take, false, false,
                                       start_position, end_position,
                                       CHANNEL, pitch, VELOCITY, true)
            end
        end
    end

    reaper.MIDI_Sort(take)
end

function Timeline.create_block(track)

    local reaper_track = reaper.GetTrack(0, track.index)
    local start_time = reaper.TimeMap2_QNToTime(0, track.next_qn)
    local end_time = reaper.TimeMap2_QNToTime(0, track.next_qn + track.beats)

    if are_items_in_range(reaper_track, start_time, end_time) then return end

    local item = reaper.CreateNewMIDIItemInProj(reaper_track, start_time, end_time, false)

    if not item then return end

    local take = reaper.GetActiveTake(item)

    if not take then return end

    insert_pattern(take, track.events, reaper.MIDI_GetPPQPosFromProjQN(take, track.next_qn))
    reaper.UpdateItemInProject(item)
    reaper.UpdateArrange()
end

return Timeline
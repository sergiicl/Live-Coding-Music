local PATTERN = {
    {60,  0.5},
    {64,  1.5},
    {58,  0.5},
    {nil, 0.5},
    {70,  1.0},
    {67, 0.5}
}

local VELOCITY        = 100
local CHANNEL         = 0

local PATTERN_FILE =
    reaper.GetResourcePath()
    .. "/Scripts/live_pattern_config.txt"

local last_content_read = nil

local function parse(content)

    local new_pattern = {}

    for line in content:gmatch("[^\r\n]+") do

        local pitch_str, dur_str = line:match("^([^,]*),([^,]+)$")

        if dur_str then

            local duration = tonumber(dur_str)
            local pitch = tonumber(pitch_str)  

            if duration then
                table.insert(new_pattern, {pitch, duration})
            end

        end

    end

    if #new_pattern == 0 then
        return nil
    end

    return new_pattern

end

local function get_create_track() 

    local track = reaper.GetSelectedTrack(0, 0)

    if track then
        return track
    end

    local num_tracks = reaper.CountTracks(0)
    reaper.InsertTrackAtIndex(num_tracks, true)
    track = reaper.GetTrack(0, num_tracks)
    reaper.SetOnlyTrackSelected(track)
    return track

end

local track = get_create_track()

local function duration_pattern(pattern)

    local total = 0

    for _, event in ipairs(pattern) do
        total = total + event[2]
    end

    return total

end

local PATTERN_LENGHT = duration_pattern(PATTERN)


local created = {}

local function reload_pattern()

    local f = io.open(PATTERN_FILE, "r")

    if not f then
        return
    end

    local content = f:read("*all")
    f:close()

    if content == last_content_read then
        return
    end

    last_content_read = content

    local new_pattern = parse(content)

    if not new_pattern then
        reaper.ShowConsoleMsg("AVISO: live_pattern_config.txt vacío o con formato inválido, se ignora.\n")
        return
    end

    PATTERN = new_pattern
    PATTERN_LENGHT = duration_pattern(PATTERN)

end


local function new_compass(start_qn)

    local end_qn = start_qn + PATTERN_LENGHT

    local start_time = reaper.TimeMap2_QNToTime(0, start_qn)
    local end_time   = reaper.TimeMap2_QNToTime(0, end_qn)

    local item = reaper.CreateNewMIDIItemInProj(track, start_time, end_time, false)

    if not item then
        return
    end

    local take = reaper.GetActiveTake(item)

    if not take then
        return
    end

    local pos_qn = start_qn

    for _, event in ipairs(PATTERN) do

        local pitch  = event[1]
        local lenght = event[2]

        if pitch ~= nil and pitch >= 0 then

            local ppq_inicio = reaper.MIDI_GetPPQPosFromProjQN(take, pos_qn)
            local ppq_final  = reaper.MIDI_GetPPQPosFromProjQN(take, pos_qn + lenght)

            reaper.MIDI_InsertNote(
                take, false, false,
                ppq_inicio, ppq_final,
                CHANNEL, pitch, VELOCITY,
                true
            )

        end

        pos_qn = pos_qn + lenght

    end

    reaper.MIDI_Sort(take)

    created[start_qn] = true

    reaper.UpdateItemInProject(item)
    reaper.UpdateArrange()

    return item

end

local function loop()

    reload_pattern()

    local playing = (reaper.GetPlayState() & 1) ~= 0

    if playing then

        local pos_qn = reaper.TimeMap2_timeToQN(0, reaper.GetPlayPosition())
        local objective =
            math.floor((pos_qn + PATTERN_LENGHT) / PATTERN_LENGHT) * PATTERN_LENGHT

        if not created[objective] then
            new_compass(objective)
        end

    end

    reaper.defer(loop)

end

loop()
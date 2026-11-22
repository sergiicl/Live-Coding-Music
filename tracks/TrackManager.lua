local Music = require('tracks.Music')
local Track = require('tracks.Track')
local Timeline = require('tracks.Timeline')
local CommandParser = require('parsing.CommandParser')

local TrackManager = { tracks = {}, track_count = 0, was_playing = false, stop = false }

function TrackManager.quit()
    TrackManager.stop = true
end

function TrackManager.parse_cmd(cmd)

    local ast = CommandParser.parse_cmd(cmd)

    local name = ast.name
    local notes = Music.parse_notes(ast.notes)
    local dur = ast.attributes["dur"] or { 1 }

    local track = rawget(TrackManager.tracks, ast.name)

    if not track then
        track = Track:new(name, TrackManager.track_count, notes, dur)
        TrackManager.tracks[name] = track
        Timeline.insert_track(track)
        TrackManager.track_count = TrackManager.track_count + 1

        reaper.ShowConsoleMsg(track:tostring() .. '\n')
    else
        TrackManager.tracks[name]:update(notes, dur)
    end

end

function TrackManager.main_loop()
    local is_playing = Timeline.is_playing()

    for name, track in pairs(TrackManager.tracks) do

        if is_playing and not TrackManager.was_playing then
            track.next_qn = nil
        end

        if is_playing then
            local actual_qn = Timeline.get_qn_play_position()

            if not track.next_qn then
                track.next_qn = math.floor(actual_qn / track.beats) * track.beats
            end

            if actual_qn + track.beats > track.next_qn then
                reaper.ShowConsoleMsg(name .. '\n')
                Timeline.create_block(track)
                track.next_qn = track.next_qn + track.beats
            end
        end
    end

    TrackManager.was_playing = is_playing

    if not TrackManager.stop then
        if TrackManager.track_count > 0 then
            reaper.ShowConsoleMsg("=============================================\n")
        end
        reaper.defer(TrackManager.main_loop)
    end
end

return TrackManager
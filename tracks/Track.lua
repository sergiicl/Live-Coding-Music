local inspect = require('libs.inspect')

Track = {
          name = nil,   -- The name of the track (string)
          index = nil,  -- The index of the track on the project (integer)
          notes = nil,  -- The notes that composes the track (table)
          dur = nil,    -- The duration of each note (table)
          events = nil, -- The MIDI events to put in the track (table)
          beats = nil,   -- The duration in beats of the MIDI events (integer)
          next_qn = nil
        }

-- =====================================
--            PRIVATE METHODS
-- =====================================

local function build_events(self)
    local events = {}
    local current_beat = 0

    for i, note in ipairs(self.notes) do
        local event_dur = self.dur[((i - 1) % #self.dur) + 1]
        local event = { start_beat = current_beat, duration = event_dur, pitches = {}, type = nil }

        if type(note) == "table" then -- Is a chord
            event.type = "chord"

            for _, chord_note in ipairs(note) do
                table.insert(event.pitches, chord_note)
            end
        else
            if note == -1 then -- Is a silence
                event.type = "rest"
            else -- Is a note
                event.type = "note"
                table.insert(event.pitches, note)
            end
        end

        table.insert(events, event)
        current_beat = current_beat + event_dur
    end

    return events, current_beat
end

-- ====================================
--            PUBLIC METHODS
-- ====================================

function Track:new(name, index, notes, dur)
    local t = {}
    setmetatable(t, self)
    self.__index = self
    -- Mandatory parameters
    self.name = name
    self.index = index
    self.notes = notes
    -- Optional parameters
    self.dur = dur

    self.events, self.beats = build_events(self)

    return self
end

function Track:update(notes, dur)
    self.notes = notes
    self.dur = dur

    self.events, self.beats = build_events(self)
end

function Track:tostring()
    return inspect(self)
end

return Track

local rtk = require('libs.rtk')
local TrackManager = require('tracks.TrackManager')

local GUI = {}

function GUI.initGUI()
    -- Create the window which runs the application
    local window = rtk.Window{title='Live Coding Prompter', w=720, h=480}

    -- Create some components
    local entry = rtk.Entry{icon=nil, placeholder='', textwidth=15} -- A text field to get user input
    local text = rtk.Text{'Type a command'} -- A text label
    local box = rtk.VBox{spacing=5} -- A vertical box to organize components

    -- Add the components to the window
    box:add(text, {halign='center'})
    box:add(entry, {halign='center'})
    window:add(box, {valign='center', halign='center'})

    entry.onkeypress = function(self, event)
        if event.keycode == rtk.keycodes.ENTER then
            local command = entry.value
            TrackManager.parse_cmd(command)
            self:clear()
        end
    end

    window.onclose = function()
        TrackManager.quit()
    end

    window:open{align='center'}
    TrackManager.main_loop()
end

return GUI
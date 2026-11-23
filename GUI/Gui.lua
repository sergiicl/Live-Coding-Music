local Gui = {}

local ctx = reaper.ImGui_CreateContext("Live Coding Music")

-- Código inicial de ejemplo en el editor
local codeBuffer = [[p1 = N(I, V, vi, IV).dur(1, 1, 1, 1)
p2 = N(c5, e5, g5, b4).dur(0.5)]]

local statusMsg = "Listo. Pulsa 'Evaluar' o Ctrl+Enter para actualizar."
local isError   = false

-- Dibuja un frame de la interfaz. Devuelve true si la ventana sigue abierta.
function Gui.draw(onEvaluateCallback)
    reaper.ImGui_SetNextWindowSize(ctx, 520, 320, reaper.ImGui_Cond_FirstUseEver())
    local visible, open = reaper.ImGui_Begin(ctx, "Live Coding Editor", true)

    if visible then
        -- Botón para evaluar el código
        if reaper.ImGui_Button(ctx, "Evaluar (Ctrl+Enter)") or
           (reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Ctrl()) and
            reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Enter())) then
            
            local ok, err = onEvaluateCallback(codeBuffer)
            if ok then
                statusMsg = "Codigo compilado correctamente"
                isError   = false
            else
                statusMsg = tostring(err)
                isError   = true
            end
        end

        reaper.ImGui_Separator(ctx)

        -- Editor de texto multilínea (ocupa todo el espacio menos el pie de estado)
        local _, availH = reaper.ImGui_GetContentRegionAvail(ctx)
        local changed, newText = reaper.ImGui_InputTextMultiline(
            ctx, "##code", codeBuffer, -1, availH - 28
        )
        if changed then
            codeBuffer = newText
        end

        -- Barra de estado / errores semánticos y sintácticos
        if isError then
            reaper.ImGui_TextColored(ctx, 0xFF5555FF, "ERROR: " .. statusMsg)
        else
            reaper.ImGui_TextColored(ctx, 0x55FF55FF, statusMsg)
        end

        reaper.ImGui_End(ctx)
    end

    return open
end

return Gui
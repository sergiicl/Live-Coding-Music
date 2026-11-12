-- live.lua
--
-- Motor en vivo. Decide CUANDO se escribe: vigila el archivo de codigo,
-- lo compila, y mientras suena Play mantiene cada patron un bloque por
-- delante del cursor. El COMO (pistas, items, notas) lo hace timeline.lua.

local Lexer = require("lexer")
local Parser = require("parser")
local Patterns = require("music")
local timeline = require("timeline")

local Live = {}

-- Cada cuantos segundos se comprueba si el archivo ha cambiado.
local CHECK_INTERVAL = 0.25


-- ==========================================================
-- ESTADO
-- ==========================================================
--
-- Cada patron (p1, p2...) tiene su propia pista y su propia cadena de
-- bloques, con la duracion de su patron (totalBeats).
--
-- STATES[nombre] = {
--     name, pattern, signature, track,
--     next_qn,        -- donde empezara el proximo bloque a crear
--     last_item,      -- ultimo bloque creado (el que va por delante)
--     last_start_qn,  -- donde empieza ese ultimo bloque
-- }

local STATES     = {}
local STATE_LIST = {}   -- mismo contenido, en orden, para recorrerlo

local sourceFile        = nil
local lastContentRead   = nil
local lastCheckTime     = 0
local missingReported   = false
local wasPlaying        = false


-- ==========================================================
-- COMPILACION: texto -> tokens -> AST -> patrones
-- ==========================================================

local function compileSource(code)

    -- Primera fase: analisis lexico.
    local tokens = Lexer.tokenize(code)

    -- Segunda fase: analisis sintactico.
    local ast = Parser.parse(tokens)

    -- Tercera fase: compilacion musical.
    local compiled = {}

    for _, assignment in ipairs(ast) do

        local pattern = Patterns.compile(assignment)

        if pattern.totalBeats > 0 then
            table.insert(compiled, pattern)
        end

    end

    if #compiled == 0 then
        error("Ningun patron tiene eventos")
    end

    return compiled

end

-- Texto que resume el contenido de un patron, para saber si cambio.
local function signature(pattern)

    local parts = { tostring(pattern.totalBeats) }

    for _, event in ipairs(pattern.events) do

        local notes = event.notes and table.concat(event.notes, "+") or "-"

        table.insert(parts,
            event.type .. ":" .. notes
            .. ":" .. tostring(event.startBeat)
            .. ":" .. tostring(event.duration)
        )

    end

    return table.concat(parts, "|")

end


-- ==========================================================
-- RECARGA EN CALIENTE
-- ==========================================================

-- El bloque que va por delante se escribio con el codigo viejo. Si
-- todavia no ha empezado a sonar, se borra y la cadena vuelve a ese punto
-- para recrearlo con el codigo nuevo.
local function discardPending(state)

    if not timeline.isPlaying() then
        return
    end

    if not timeline.isItemValid(state.last_item) then
        return
    end

    if state.last_start_qn > timeline.getPlayPositionQN() then

        timeline.deleteItem(state.last_item)

        state.next_qn   = state.last_start_qn
        state.last_item = nil

    end

end

local function applyCompiled(compiled)

    local seen = {}

    for _, pattern in ipairs(compiled) do

        seen[pattern.name] = true

        local state = STATES[pattern.name]

        if not state then
            state = { name = pattern.name }
            STATES[pattern.name] = state
            table.insert(STATE_LIST, state)
        end

        state.pattern = pattern

        -- Solo se toca la pista de un patron si su contenido cambio.
        local newSignature = signature(pattern)

        if state.signature ~= newSignature then
            state.signature = newSignature
            discardPending(state)
        end

    end

    -- Patrones que ya no estan en el archivo: se dejan de generar.
    for i = #STATE_LIST, 1, -1 do

        local state = STATE_LIST[i]

        if not seen[state.name] then
            discardPending(state)
            STATES[state.name] = nil
            table.remove(STATE_LIST, i)
        end

    end

end

local function reloadSource()

    local now = reaper.time_precise()

    if now - lastCheckTime < CHECK_INTERVAL then
        return
    end

    lastCheckTime = now

    local file = io.open(sourceFile, "r")

    if not file then

        if not missingReported then
            reaper.ShowConsoleMsg("No se ha encontrado " .. sourceFile .. "\n")
            missingReported = true
        end

        return

    end

    missingReported = false

    local code = file:read("*a")
    file:close()

    if code == lastContentRead then
        return
    end

    lastContentRead = code

    -- Si el codigo tiene errores se avisa y se sigue con lo anterior.
    local ok, result = pcall(compileSource, code)

    if not ok then
        reaper.ShowConsoleMsg("ERROR en el codigo: " .. tostring(result) .. "\n")
        return
    end

    applyCompiled(result)

    reaper.ShowConsoleMsg("CODIGO RECARGADO (" .. #STATE_LIST .. " patrones)\n")

end


-- ==========================================================
-- BUCLE PRINCIPAL
-- ==========================================================

local function loop()

    reloadSource()

    local playing = timeline.isPlaying()

    -- Al dar a Play cada cadena se recalcula desde donde esta el cursor.
    if playing and not wasPlaying then

        for _, state in ipairs(STATE_LIST) do
            state.next_qn = nil
        end

    end

    wasPlaying = playing

    if playing then

        local posQN = timeline.getPlayPositionQN()

        for _, state in ipairs(STATE_LIST) do

            local length = state.pattern.totalBeats

            -- Primer bloque: el que contiene la posicion actual.
            if state.next_qn == nil then
                state.next_qn = math.floor(posQN / length) * length
            end

            -- Cada pista mantiene un bloque por delante del cursor.
            if posQN + length > state.next_qn then

                state.track = timeline.getTrack(state.name, state.track)

                local item = timeline.createBlock(state.track, state.pattern, state.next_qn)

                if item then
                    state.last_item     = item
                    state.last_start_qn = state.next_qn
                end

                state.next_qn = state.next_qn + length

            end

        end

    end

    reaper.defer(loop)

end


-- ==========================================================
-- API PUBLICA
-- ==========================================================

function Live.start(path)

    sourceFile = path

    reaper.ShowConsoleMsg("=== LIVE CODING LISTO: edita el archivo y dale a Play ===\n")

    loop()

end

return Live
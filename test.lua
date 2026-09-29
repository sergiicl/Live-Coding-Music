-- ==========================================================
-- LIVE PATTERN (Sin afectar compases anteriores al reiniciar)
-- ==========================================================

--------------------------------------------------------------
-- CONFIGURACIÓN
--------------------------------------------------------------

local patron = {   -- C4
      -- Silencio
    {65, 0.5},   -- G4
    {64, 1.5},   -- E4
    {58, 0.5},    -- A4
    {nil, 0.5},
    {60, 1.0},
}
 
local VELOCIDAD = 100
local CANAL = 0
local ANTICIPACION_QN = 1.0

--------------------------------------------------------------
-- VALIDAR Y CALCULAR PATRÓN
--------------------------------------------------------------

local duracion_patron = 0
for _, evento in ipairs(patron) do
    duracion_patron = duracion_patron + evento[2]
end

if duracion_patron <= 0 then return end

local track = reaper.GetSelectedTrack(0, 0)
if not track then
    reaper.ShowMessageBox("Selecciona una pista MIDI.", "Error", 0)
    return
end

--------------------------------------------------------------
-- ESTADO E INICIALIZACIÓN
--------------------------------------------------------------

local compases_creados = {}

-- Determinamos la posición actual real (si está sonando o parado)
local play_state = reaper.GetPlayState()
local posicion_actual = (play_state & 1 ~= 0) and reaper.GetPlayPosition() or reaper.GetCursorPosition()
local qn_actual = reaper.TimeMap2_timeToQN(0, posicion_actual)

-- El siguiente compás SIEMPRE será el próximo bloque limpio por delante de donde estamos
local compas_siguiente = math.ceil(qn_actual / duracion_patron) * duracion_patron

--------------------------------------------------------------
-- CREAR UN BLOQUE DEL PATRÓN
--------------------------------------------------------------

function crear_compas(inicio_qn)

    local final_qn = inicio_qn + duracion_patron

    local inicio_tiempo = reaper.TimeMap2_QNToTime(0, inicio_qn)
    local final_tiempo = reaper.TimeMap2_QNToTime(0, final_qn)

    local item = reaper.CreateNewMIDIItemInProj(track, inicio_tiempo, final_tiempo, false)
    if not item then return end

    local take = reaper.GetActiveTake(item)
    if not take then return end

    reaper.GetSetMediaItemInfo_String(item, "P_NAME", "LIVE_PATTERN", true)

    local posicion_actual_qn = inicio_qn

    for _, evento in ipairs(patron) do
        local pitch = evento[1]
        local duracion_nota = evento[2]

        if pitch ~= nil and pitch >= 0 then
            local ppq_inicio = reaper.MIDI_GetPPQPosFromProjQN(take, posicion_actual_qn)
            local ppq_final = reaper.MIDI_GetPPQPosFromProjQN(take, posicion_actual_qn + duracion_nota)

            reaper.MIDI_InsertNote(
                take, false, false, ppq_inicio, ppq_final, CANAL, pitch, VELOCIDAD, true
            )
        end
        posicion_actual_qn = posicion_actual_qn + duracion_nota
    end

    reaper.MIDI_Sort(take)
    compases_creados[inicio_qn] = true
    reaper.UpdateItemInProject(item)
end

--------------------------------------------------------------
-- BUCLE DE REPRODUCCIÓN
--------------------------------------------------------------

function loop()

    local play_state_loop = reaper.GetPlayState()

    if play_state_loop & 1 ~= 0 then

        local posicion = reaper.GetPlayPosition()
        local play_qn = reaper.TimeMap2_timeToQN(0, posicion)

        local limite = compas_siguiente - ANTICIPACION_QN

        if play_qn >= limite then
            if not compases_creados[compas_siguiente] then
                crear_compas(compas_siguiente)
                compas_siguiente = compas_siguiente + duracion_patron
            end
        end
    end

    reaper.defer(loop)
end

--------------------------------------------------------------
-- INICIAR
--------------------------------------------------------------

reaper.ShowConsoleMsg("=== LIVE PATTERN ACTUALIZADO ===\n")
loop()

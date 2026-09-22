-- ==========================================================
-- LIVE CODING RECEPCIONISTA - REAPER
-- ==========================================================
--
-- Lee comandos desde:
--
-- C:\Users\TU_USUARIO\AppData\Roaming\REAPER\Scripts\
-- livecoding_cmd.txt
--
--
-- COMANDOS:
--
-- crear_nota pista=0 nota=60 inicio=0 duracion=1
--
-- eliminar_nota pista=0 nota=60 inicio=0
--
-- eliminar_nota pista=0 nota=60
--
--
-- "inicio" y "duracion" están expresados en BEATS / QN
-- dentro del patrón.
--
-- El patrón se repite automáticamente.
--
-- Un comando recibido durante un ciclo se aplica
-- al principio del siguiente.
--
-- La lógica de ciclos SOLO funciona mientras el
-- transporte está reproduciendo.
-- ==========================================================


-- ==========================================================
-- CONFIGURACIÓN
-- ==========================================================

local COMMAND_FILE =
    reaper.GetResourcePath()
    .. "/Scripts/livecoding_cmd.txt"

-- Número de compases que forman un ciclo
local COMPASES_POR_CICLO = 1

-- Cuánto dejamos de duración al ITEM.
-- El source MIDI seguirá siendo el patrón que se repite.
local DURACION_ITEM = 3600

-- Margen de seguridad (en segundos) para anticipar el cruce
-- de ciclo antes de que el motor de audio lea ese punto.
-- Ajusta este valor según el tamaño de buffer de tu audio.
local MARGEN_SEGURIDAD = 0.05


-- ==========================================================
-- VARIABLES DE ESTADO
-- ==========================================================

-- Comandos pendientes agrupados por ciclo.
--
-- comandos_pendientes[5] = {
--     {tipo="crear_nota", args={...}},
--     {tipo="eliminar_nota", args={...}}
-- }
--
local comandos_pendientes = {}

-- Item MIDI activo por pista
local item_activo = {}

-- Último ciclo procesado
local ultimo_ciclo = -1


-- ==========================================================
-- ESTADO DE REPRODUCCIÓN
-- ==========================================================
--
-- Solo tiene sentido hablar de "ciclos" mientras el
-- transporte está reproduciendo. GetPlayPosition2() no es
-- fiable cuando el proyecto está parado, así que bloqueamos
-- toda la lógica de ciclos en ese caso.
-- ==========================================================

function esta_reproduciendo()

    local estado =
        reaper.GetPlayState()

    -- bit 0 = reproduciendo, bit 1 = pausado, bit 2 = grabando
    return (estado & 1) == 1

end


-- ==========================================================
-- PARSEAR ARGUMENTOS
-- ==========================================================

function parse_args(text)

    local args = {}

    for key, value in text:gmatch(
        "([%w_]+)=([%-]?[%d%.]+)"
    ) do

        args[key] = tonumber(value)

    end

    return args

end


-- ==========================================================
-- OBTENER CICLO ACTUAL
-- ==========================================================
--
-- Usamos GetPlayPosition2(), que da la posición del bloque
-- que el motor de audio está procesando ahora mismo (no la
-- posición compensada por latencia de lo que se oye), más
-- un margen de seguridad extra para anticiparnos al jitter
-- de la cadencia de defer.
-- ==========================================================

function ciclo_actual()

    local pos =
        reaper.GetPlayPosition2()
        + MARGEN_SEGURIDAD

    local beats, measures =
        reaper.TimeMap2_timeToBeats(
            0,
            pos
        )

    if measures == nil then
        return 0
    end

    return math.floor(
        measures / COMPASES_POR_CICLO
    )

end


-- ==========================================================
-- INFORMACIÓN DEL CICLO
-- ==========================================================

function obtener_info_ciclo(ciclo)

    ----------------------------------------------------------
    -- Buscamos una QN aproximada para ese compás.
    --
    -- En 4/4 esto corresponde directamente a:
    -- ciclo * 4
    --
    -- Luego REAPER corrige según el mapa de tempo / métrica.
    ----------------------------------------------------------

    local qn_aprox =
        ciclo
        * COMPASES_POR_CICLO
        * 4


    local _, inicio_qn, fin_qn =
        reaper.TimeMap_QNToMeasures(
            0,
            qn_aprox
        )


    if inicio_qn == nil then
        inicio_qn = qn_aprox
    end


    if fin_qn == nil then

        fin_qn =
            inicio_qn
            + (
                COMPASES_POR_CICLO * 4
            )

    end


    ----------------------------------------------------------
    -- Pasar QN -> tiempo.
    ----------------------------------------------------------

    local inicio_tiempo =
        reaper.TimeMap2_QNToTime(
            0,
            inicio_qn
        )


    local fin_tiempo =
        reaper.TimeMap2_QNToTime(
            0,
            fin_qn
        )


    return {
        inicio_qn = inicio_qn,
        fin_qn = fin_qn,
        inicio_tiempo = inicio_tiempo,
        fin_tiempo = fin_tiempo
    }

end


-- ==========================================================
-- CREAR ITEM MIDI
-- ==========================================================

function crear_item(
    pista,
    ciclo
)

    local track =
        reaper.GetTrack(
            0,
            pista
        )


    if not track then

        reaper.ShowConsoleMsg(
            "ERROR: no existe la pista "
            .. tostring(pista)
            .. "\n"
        )

        return nil

    end


    local info =
        obtener_info_ciclo(ciclo)


    ----------------------------------------------------------
    -- Crear ITEM MIDI.
    --
    -- qnIn = true
    -- => las posiciones son QN.
    ----------------------------------------------------------

    local item =
        reaper.CreateNewMIDIItemInProj(
            track,
            info.inicio_qn,
            info.fin_qn,
            true
        )


    if not item then

        reaper.ShowConsoleMsg(
            "ERROR: no se pudo crear el item MIDI\n"
        )

        return nil

    end


    ----------------------------------------------------------
    -- El item sigue el tiempo musical.
    ----------------------------------------------------------

    reaper.SetMediaItemInfo_Value(
        item,
        "C_BEATATTACHMODE",
        1
    )


    ----------------------------------------------------------
    -- Activar looping del SOURCE.
    ----------------------------------------------------------

    reaper.SetMediaItemInfo_Value(
        item,
        "B_LOOPSRC",
        1
    )


    ----------------------------------------------------------
    -- Alargar el ITEM.
    --
    -- El source MIDI es solamente de un ciclo.
    -- REAPER reutiliza ese source durante toda
    -- la duración del item.
    ----------------------------------------------------------

    reaper.SetMediaItemLength(
        item,
        DURACION_ITEM,
        false
    )


    reaper.UpdateArrange()


    reaper.ShowConsoleMsg(
        "ITEM CREADO -> pista="
        .. pista
        .. " ciclo="
        .. ciclo
        .. "\n"
    )


    return item

end


-- ==========================================================
-- OBTENER ITEM DE UNA PISTA
-- ==========================================================

function obtener_item(
    pista,
    ciclo
)

    local item =
        item_activo[pista]


    ----------------------------------------------------------
    -- Si ya existe, lo reutilizamos.
    ----------------------------------------------------------

    if item then

        return item

    end


    ----------------------------------------------------------
    -- Si no existe, crear.
    ----------------------------------------------------------

    item =
        crear_item(
            pista,
            ciclo
        )


    if item then

        item_activo[pista] =
            item

    end


    return item

end


-- ==========================================================
-- CREAR NOTA
-- ==========================================================

function crear_nota(args)

    if args.pista == nil then

        reaper.ShowConsoleMsg(
            "ERROR crear_nota: falta pista\n"
        )

        return

    end


    if args.nota == nil then

        reaper.ShowConsoleMsg(
            "ERROR crear_nota: falta nota\n"
        )

        return

    end


    if args.inicio == nil then

        reaper.ShowConsoleMsg(
            "ERROR crear_nota: falta inicio\n"
        )

        return

    end


    if args.duracion == nil then

        reaper.ShowConsoleMsg(
            "ERROR crear_nota: falta duracion\n"
        )

        return

    end


    ----------------------------------------------------------
    -- Obtener item
    ----------------------------------------------------------

    local item =
        obtener_item(
            args.pista,
            ciclo_actual()
        )


    if not item then
        return
    end


    ----------------------------------------------------------
    -- TAKE
    ----------------------------------------------------------

    local take =
        reaper.GetActiveTake(
            item
        )


    if not take then

        reaper.ShowConsoleMsg(
            "ERROR: el item no tiene take MIDI\n"
        )

        return

    end


    ----------------------------------------------------------
    -- QN de inicio del ITEM
    ----------------------------------------------------------

    local item_position =
        reaper.GetMediaItemInfo_Value(
            item,
            "D_POSITION"
        )


    local item_start_qn =
        reaper.TimeMap2_timeToQN(
            0,
            item_position
        )


    ----------------------------------------------------------
    -- Posición de la nota dentro del patrón.
    --
    -- inicio=0
    -- inicio=1
    -- inicio=2
    -- inicio=3
    --
    -- etc.
    ----------------------------------------------------------

    local start_qn =
        item_start_qn
        + args.inicio


    local end_qn =
        start_qn
        + args.duracion


    ----------------------------------------------------------
    -- QN -> PPQ
    ----------------------------------------------------------

    local start_ppq =
        reaper.MIDI_GetPPQPosFromProjQN(
            take,
            start_qn
        )


    local end_ppq =
        reaper.MIDI_GetPPQPosFromProjQN(
            take,
            end_qn
        )


    ----------------------------------------------------------
    -- Velocidad
    ----------------------------------------------------------

    local velocidad =
        args.velocidad or 100


    if velocidad < 1 then
        velocidad = 1
    end


    if velocidad > 127 then
        velocidad = 127
    end


    ----------------------------------------------------------
    -- INSERTAR NOTA
    ----------------------------------------------------------

    reaper.MIDI_InsertNote(
        take,
        false,
        false,
        start_ppq,
        end_ppq,
        0,
        args.nota,
        velocidad,
        false
    )


    reaper.MIDI_Sort(
        take
    )


    ----------------------------------------------------------
    -- ACTUALIZAR EDITOR MIDI
    --
    -- IMPORTANTE:
    -- MIDI_RefreshEditors NECESITA 'take'.
    ----------------------------------------------------------

    reaper.MIDI_RefreshEditors(
        take
    )


    reaper.UpdateArrange()


    reaper.ShowConsoleMsg(
        "CREAR -> "
        .. "pista="
        .. args.pista
        .. " nota="
        .. args.nota
        .. " inicio="
        .. args.inicio
        .. " duracion="
        .. args.duracion
        .. "\n"
    )

end


-- ==========================================================
-- ELIMINAR NOTA
-- ==========================================================

function eliminar_nota(args)

    if args.pista == nil then

        reaper.ShowConsoleMsg(
            "ERROR eliminar_nota: falta pista\n"
        )

        return

    end


    if args.nota == nil then

        reaper.ShowConsoleMsg(
            "ERROR eliminar_nota: falta nota\n"
        )

        return

    end


    ----------------------------------------------------------
    -- Buscar item
    ----------------------------------------------------------

    local item =
        item_activo[
            args.pista
        ]


    if not item then

        reaper.ShowConsoleMsg(
            "No existe item en pista "
            .. args.pista
            .. "\n"
        )

        return

    end


    ----------------------------------------------------------
    -- TAKE
    ----------------------------------------------------------

    local take =
        reaper.GetActiveTake(
            item
        )


    if not take then

        reaper.ShowConsoleMsg(
            "ERROR: no existe take MIDI\n"
        )

        return

    end


    ----------------------------------------------------------
    -- Posición de inicio de la nota
    ----------------------------------------------------------

    local inicio_ppq = nil


    if args.inicio ~= nil then

        local item_position =
            reaper.GetMediaItemInfo_Value(
                item,
                "D_POSITION"
            )


        local item_start_qn =
            reaper.TimeMap2_timeToQN(
                0,
                item_position
            )


        local nota_qn =
            item_start_qn
            + args.inicio


        inicio_ppq =
            reaper.MIDI_GetPPQPosFromProjQN(
                take,
                nota_qn
            )

    end


    ----------------------------------------------------------
    -- CONTAR NOTAS
    ----------------------------------------------------------

    local _, num_notes =
        reaper.MIDI_CountEvts(
            take
        )


    ----------------------------------------------------------
    -- RECORRER LAS NOTAS
    --
    -- De atrás hacia adelante porque vamos eliminando.
    ----------------------------------------------------------

    for i = num_notes - 1, 0, -1 do

        local ok,
              selected,
              muted,
              start_ppq,
              end_ppq,
              chan,
              pitch,
              velocity =
            reaper.MIDI_GetNote(
                take,
                i
            )


        if ok and pitch == args.nota then

            --------------------------------------------------
            -- CON inicio:
            --
            -- eliminar solamente la nota situada
            -- en ese beat.
            --------------------------------------------------

            if inicio_ppq ~= nil then

                local diferencia =
                    math.abs(
                        start_ppq
                        - inicio_ppq
                    )


                if diferencia <= 1 then

                    reaper.MIDI_DeleteNote(
                        take,
                        i
                    )


                    reaper.ShowConsoleMsg(
                        "ELIMINAR -> "
                        .. "pista="
                        .. args.pista
                        .. " nota="
                        .. args.nota
                        .. " inicio="
                        .. args.inicio
                        .. "\n"
                    )

                end


            --------------------------------------------------
            -- SIN inicio:
            --
            -- eliminar todas las notas de ese pitch.
            --------------------------------------------------

            else

                reaper.MIDI_DeleteNote(
                    take,
                    i
                )


                reaper.ShowConsoleMsg(
                    "ELIMINAR -> "
                    .. "pista="
                    .. args.pista
                    .. " nota="
                    .. args.nota
                    .. "\n"
                )

            end

        end

    end


    ----------------------------------------------------------
    -- Ordenar MIDI
    ----------------------------------------------------------

    reaper.MIDI_Sort(
        take
    )


    ----------------------------------------------------------
    -- Actualizar editor MIDI
    ----------------------------------------------------------

    reaper.MIDI_RefreshEditors(
        take
    )


    reaper.UpdateArrange()

end


-- ==========================================================
-- ENCOLAR COMANDO
-- ==========================================================

function encolar_comando(
    tipo,
    args
)

    ----------------------------------------------------------
    -- Saber en qué ciclo estamos cuando recibimos
    -- el comando.
    ----------------------------------------------------------

    local ciclo_recibido =
        ciclo_actual()


    ----------------------------------------------------------
    -- SIEMPRE APLICAR EN EL SIGUIENTE CICLO.
    ----------------------------------------------------------

    local ciclo_objetivo =
        ciclo_recibido + 1


    ----------------------------------------------------------
    -- Crear cola si no existe.
    ----------------------------------------------------------

    if not comandos_pendientes[
        ciclo_objetivo
    ] then

        comandos_pendientes[
            ciclo_objetivo
        ] = {}

    end


    ----------------------------------------------------------
    -- Añadir comando
    ----------------------------------------------------------

    table.insert(
        comandos_pendientes[
            ciclo_objetivo
        ],
        {
            tipo = tipo,
            args = args
        }
    )


    ----------------------------------------------------------
    -- Si es la primera nota de una pista,
    -- preparar el item ya en el ciclo objetivo.
    ----------------------------------------------------------

    if tipo == "crear_nota" then

        if not item_activo[
            args.pista
        ] then

            item_activo[
                args.pista
            ] =
                crear_item(
                    args.pista,
                    ciclo_objetivo
                )

        end

    end


    reaper.ShowConsoleMsg(
        "EN COLA -> "
        .. tipo
        .. " -> ciclo "
        .. ciclo_objetivo
        .. "\n"
    )

end


-- ==========================================================
-- PROCESAR TEXTO RECIBIDO
-- ==========================================================

function procesar_comando(
    command_text
)

    command_text =
        command_text:match(
            "^%s*(.-)%s*$"
        )


    if command_text == "" then
        return
    end


    ----------------------------------------------------------
    -- Separar comando y argumentos.
    ----------------------------------------------------------

    local comando,
          resto =
        command_text:match(
            "^(%S+)%s*(.*)$"
        )


    if not comando then
        return
    end


    local args =
        parse_args(
            resto
        )


    ----------------------------------------------------------
    -- CREAR
    ----------------------------------------------------------

    if comando == "crear_nota" then

        encolar_comando(
            "crear_nota",
            args
        )


    ----------------------------------------------------------
    -- ELIMINAR
    ----------------------------------------------------------

    elseif comando == "eliminar_nota" then

        encolar_comando(
            "eliminar_nota",
            args
        )


    ----------------------------------------------------------
    -- DESCONOCIDO
    ----------------------------------------------------------

    else

        reaper.ShowConsoleMsg(
            "Comando desconocido: "
            .. tostring(comando)
            .. "\n"
        )

    end

end


-- ==========================================================
-- LEER ARCHIVO
-- ==========================================================

function leer_comandos()

    local file =
        io.open(
            COMMAND_FILE,
            "r"
        )


    if not file then
        return
    end


    local content =
        file:read("*all")


    file:close()


    if not content then
        return
    end


    if content == "" then
        return
    end


    ----------------------------------------------------------
    -- Un comando por línea.
    ----------------------------------------------------------

    for linea in content:gmatch(
        "[^\r\n]+"
    ) do

        procesar_comando(
            linea
        )

    end


    ----------------------------------------------------------
    -- Vaciar archivo
    ----------------------------------------------------------

    local clear =
        io.open(
            COMMAND_FILE,
            "w"
        )


    if clear then

        clear:write("")

        clear:close()

    end

end


-- ==========================================================
-- APLICAR COMANDOS DE UN CICLO
-- ==========================================================

function aplicar_comandos(
    ciclo
)

    local comandos =
        comandos_pendientes[
            ciclo
        ]


    if not comandos then
        return
    end


    ----------------------------------------------------------
    -- Un solo Undo para todos los cambios.
    ----------------------------------------------------------

    reaper.Undo_BeginBlock()


    ----------------------------------------------------------
    -- Aplicar comandos en orden.
    ----------------------------------------------------------

    for _, comando in ipairs(
        comandos
    ) do

        if comando.tipo == "crear_nota" then

            crear_nota(
                comando.args
            )


        elseif comando.tipo == "eliminar_nota" then

            eliminar_nota(
                comando.args
            )

        end

    end


    ----------------------------------------------------------
    -- Finalizar Undo.
    ----------------------------------------------------------

    reaper.Undo_EndBlock(
        "Live Coding - ciclo "
        .. ciclo,
        -1
    )


    ----------------------------------------------------------
    -- Vaciar cola.
    ----------------------------------------------------------

    comandos_pendientes[
        ciclo
    ] = nil

end


-- ==========================================================
-- LOOP PRINCIPAL
-- ==========================================================

function loop()

    ----------------------------------------------------------
    -- 1. Leer comandos de Python
    ----------------------------------------------------------

    leer_comandos()


    ----------------------------------------------------------
    -- 2. Solo procesar ciclos mientras se reproduce.
    --
    -- GetPlayPosition2() no es fiable con el transporte
    -- parado, así que evitamos calcular o avanzar ciclos
    -- en ese caso.
    ----------------------------------------------------------

    if esta_reproduciendo() then

        local ciclo =
            ciclo_actual()


        ------------------------------------------------------
        -- 3. ¿Hemos entrado en un ciclo nuevo?
        ------------------------------------------------------

        if ciclo ~= ultimo_ciclo then

            reaper.ShowConsoleMsg(
                "\n"
                .. "==============================\n"
                .. " NUEVO CICLO: "
                .. ciclo
                .. "\n"
                .. "==============================\n"
            )


            aplicar_comandos(
                ciclo
            )


            ultimo_ciclo =
                ciclo

        end

    end


    ----------------------------------------------------------
    -- 4. Continuar ejecutando.
    ----------------------------------------------------------

    reaper.defer(
        loop
    )

end


-- ==========================================================
-- INICIO
-- ==========================================================
--
-- No calculamos el ciclo inicial aquí: con el transporte
-- parado, GetPlayPosition2() no es fiable. Se ajustará solo
-- en cuanto se pulse Play.
-- ==========================================================

ultimo_ciclo = -1


reaper.ShowConsoleMsg(
    "\n"
    .. "=====================================\n"
    .. " LIVE CODING RECEPCIONISTA INICIADO\n"
    .. "=====================================\n"
    .. "Esperando comandos...\n"
)


loop()

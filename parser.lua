
local Parser = {}

function Parser.parse(tokens)
    -- position apunta al siguiente token que todavía no se ha consumido.
    local position = 1

    -- Consulta el token actual sin avanzar.
    local function peek()
        return tokens[position]
    end

    -- Consume un token y comprueba que pertenece al tipo esperado.
    local function consume(expectedType)
        local token = peek()

        if not token then
            error("Fin inesperado del codigo")
        end

        if token.type ~= expectedType then
            error("Se esperaba " .. expectedType ..
                " pero se encontro " .. token.type)
        end

        position = position + 1
        return token
    end

    -- Convierte un token NOTE en un nodo de nota del AST.
    local function parseNote()
        local token = consume("NOTE")

        return {
            type = "note",
            value = token.value
        }
    end

    -- Analiza un acorde
    local function parseChord()
        consume("LEFT_BRACKET")

        local notes = {}

        -- Un acorde debe contener al menos una nota.
        table.insert(notes, parseNote())

        while peek() and peek().type == "COMMA" do
            consume("COMMA")
            table.insert(notes, parseNote())
        end

        consume("RIGHT_BRACKET")

        return {
            type = "chord",
            notes = notes
        }
    end

    -- Analiza uno de los eventos permitidos dentro de un patrón:
    -- una nota, un silencio o un acorde.
    local function parseEvent()
        local token = peek()

        if not token then
            error("Se esperaba un evento musical, pero termino el codigo")
        end

        if token.type == "NOTE" then
            return parseNote()

        elseif token.type == "REST" then
            consume("REST")

            return {
                type = "rest"
            }

        elseif token.type == "LEFT_BRACKET" then
            return parseChord()

        else
            error("Evento musical no valido: " .. token.type)
        end
    end

    -- Analiza una llamada N(evento, evento, ...), seguida opcionalmente
    -- de la propiedad .dur(numero).
    local function parsePattern()
        consume("PATTERN")
        consume("LEFT_PAREN")

        local events = {}

        -- Se permiten patrones vacíos, por ejemplo N().
        if peek() and peek().type ~= "RIGHT_PAREN" then
            table.insert(events, parseEvent())

            while peek() and peek().type == "COMMA" do
                consume("COMMA")
                table.insert(events, parseEvent())
            end
        end

        consume("RIGHT_PAREN")

        -- La duración se expresa en beats y, si no aparece, vale 0.5.
        local duration = 0.5

        if peek() and peek().type == "DURATION" then
            consume("DURATION")
            consume("LEFT_PAREN")

            duration = consume("NUMBER").value

            consume("RIGHT_PAREN")

            -- Una duración cero o negativa no produciría un evento válido.
            if duration <= 0 then
                error("La duracion debe ser mayor que cero")
            end
        end

        return {
            type = "pattern",
            events = events,
            duration = duration
        }
    end

    -- Analiza una asignación completa: nombre = patrón.
    local function parseAssignment()
        local name = consume("IDENTIFIER").value

        consume("ASSIGN")

        local pattern = parsePattern()

        return {
            type = "assignment",
            name = name,
            pattern = pattern
        }
    end

    -- El lenguaje actual admite exactamente una asignación por entrada.
    local assignments = {}

    while position <= #tokens do
        table.insert(assignments, parseAssignment())
    end

    if #assignments == 0 then
        error("No se ha definido ningun patron musical")
    end

    return assignments
end

return Parser

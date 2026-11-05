
local Lexer = {}

-- Comprueba si un caracter es una letra.
local function isLetter(char)
    return char and char:match("%a") ~= nil
end

-- Comprueba si un caracter es un digito.
local function isDigit(char)
    return char and char:match("%d") ~= nil
end

-- Comprueba si un caracter es un espacio.
local function isSpace(char)
    return char and char:match("%s") ~= nil
end

function Lexer.tokenize(input)
    local tokens = {}
    local position = 1

    -- Añade un token a la lista.
    local function addToken(tokenType, value)
        table.insert(tokens, {
            type = tokenType,
            value = value
        })
    end

    while position <= #input do
        local char = input:sub(position, position)

        if isSpace(char) then
            position = position + 1

        elseif char == "=" then
            addToken("ASSIGN", char)
            position = position + 1

        elseif char == "(" then
            addToken("LEFT_PAREN", char)
            position = position + 1

        elseif char == ")" then
            addToken("RIGHT_PAREN", char)
            position = position + 1

        elseif char == "[" then
            addToken("LEFT_BRACKET", char)
            position = position + 1

        elseif char == "]" then
            addToken("RIGHT_BRACKET", char)
            position = position + 1

        elseif char == "," then
            addToken("COMMA", char)
            position = position + 1

        elseif char == "-" then
            addToken("REST", char)
            position = position + 1

        -- Reconoce la propiedad .dur.
        elseif char == "." then
            if input:sub(position, position + 3) == ".dur" then
                addToken("DURATION", ".dur")
                position = position + 4
            else
                error("Propiedad no reconocida en posicion " .. position)
            end

        -- Reconoce numeros enteros y decimales.
        elseif isDigit(char) then
            local start = position

            while isDigit(input:sub(position, position)) do
                position = position + 1
            end

            if input:sub(position, position) == "."
                and isDigit(input:sub(position + 1, position + 1)) then

                position = position + 1

                while isDigit(input:sub(position, position)) do
                    position = position + 1
                end
            end

            local value = input:sub(start, position - 1)
            addToken("NUMBER", tonumber(value))

        -- Reconoce patrones, notas e identificadores.
        elseif isLetter(char) then
            local start = position

            while isLetter(input:sub(position, position))
                or isDigit(input:sub(position, position)) do
                position = position + 1
            end

            local word = input:sub(start, position - 1)

            if word == "N" then
                addToken("PATTERN", word)

            elseif word:match("^[cdefgab]%d+$") then
                addToken("NOTE", word)

            else
                addToken("IDENTIFIER", word)
            end

        else
            error("Caracter no reconocido: " .. char)
        end
    end

    return tokens
end

return Lexer

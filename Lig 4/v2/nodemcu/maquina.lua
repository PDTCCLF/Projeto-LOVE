local beep = dofile("beep.lua")
local function criaMaquina(consts)
    local led1 = consts.led1
    local led2 = consts.led2
    local mysplit = consts.mysplit
    local matriz = consts.matriz
    local topic = consts.topic
    local meuid = consts.meuid

    maquina = {
        inicio = {
            botao1 = function(l, t)
                print("Botao 1 pressionado")
            end,
            botao2 = function(l, t)
                print("Botao 2 pressionado")
            end,
            botao3 = function(l, t)
                print("Botao 3 pressionado")
            end,
            botao4 = function(l, t)
                print("Botao 4 pressionado")
                gpio.write(led1, gpio.LOW);
                gpio.write(led2, gpio.LOW);
                consts.estado = "conectando"
                conecta_cliente()
            end
        },
        conectando = {
            subscribe = function(client)
                print("Conectado")
                print("Inscrito")
                gpio.write(led1, gpio.LOW);
                gpio.write(led2, gpio.LOW);
                consts.estado = "espera"
                local msg = meuid .. ",BROADCAST,NIL"
                consts.m:publish(topic, msg, 0, 0, function(client) print(msg) end)
            end,
            confail = function(client)
                gpio.write(led1, gpio.HIGH);
                gpio.write(led2, gpio.LOW);
                consts.estado = "inicio"
            end
        },
        espera = {
            botao4 = function(l, t)
                local msg = meuid .. ",BROADCAST,NIL"
                consts.m:publish(topic, msg, 0, 0, function(client) print(msg) end)
            end,
            message = function(client, topic, message)
                --print("Mensagem '" .. message .. "' recebida")
                local tmsg = mysplit(message, ",")
                if tmsg[1] == meuid then
                    return
                elseif tmsg[2] == meuid then
                    print(tmsg[3])
                    salas = mysplit(tmsg[3], ";")
                    consts.estado = "escolhendo"
                    consts.x = 0
                    gpio.write(led1, gpio.LOW);
                    gpio.write(led2, gpio.HIGH);
                end
            end
        },
        escolhendo = {
            botao1 = function(l, t)
                if consts.x > 0 then
                    consts.x = consts.x - 1
                    print("x=" .. consts.x)
                    print("sala=" .. (salas[consts.x] or "nil"))
                    if salas[consts.x] == nil then return end
                    local sala = salas[consts.x]
                    local notas = {}
                    for i = 1, sala:len() do
                        notas[i] = { sala:sub(i, i), 100 }
                    end
                    beep(notas)
                end
            end,
            botao2 = function(l, t)
                if salas[consts.x + 1] ~= nil then
                    consts.x = consts.x + 1
                    print("x=" .. consts.x)
                    print("sala=" .. (salas[consts.x] or "nil"))
                    if salas[consts.x] == nil then return end
                    local sala = salas[consts.x]
                    local notas = {}
                    for i = 1, sala:len() do
                        notas[i] = { sala:sub(i, i), 100 }
                    end
                    beep(notas)
                end
            end,
            botao4 = function(l, t)
                if consts.x == 0 then return end
                consts.estado = "entrando"
                gpio.write(led1, gpio.LOW);
                gpio.write(led2, gpio.LOW);
                local msg = meuid .. ",BROADCAST," .. salas[consts.x] .. ",SUB"
                consts.m:publish(topic, msg, 0, 0, function(client) print(msg) end)
            end
        },
        entrando = {
            message = function(client, topic, message)
                local tmsg = mysplit(message, ",")
                if tmsg[1] == meuid then
                    return
                elseif tmsg[2] == meuid then
                    if tmsg[4] == "JOG1" then
                        -- server_id,node_id,salax,JOG1
                        consts.sala = tmsg[3]
                        consts.estado = "jogo1"
                        gpio.write(led1, gpio.LOW);
                        gpio.write(led2, gpio.HIGH);
                    elseif tmsg[4] == "JOG2" then
                        -- server_id,node_id,salax,JOG2
                        consts.sala = tmsg[3]
                        consts.estado = "jogo2"
                        gpio.write(led1, gpio.HIGH);
                        gpio.write(led2, gpio.LOW);
                    elseif tmsg[4] == "NEG" then
                        -- server_id,node_id,salax,NEG
                        consts.estado = "espera"
                    end
                    print("Mensagem '" .. message .. "' recebida")
                end
            end
        },
        jogo1 = {
            botao1 = function(l, t)
                print("<-<-<")
                consts.x = (consts.x - 2) % 7 + 1
                print("x=" .. consts.x)
                msg = meuid .. ",BROADCAST," .. consts.sala .. ",MOV," .. consts.x
                consts.m:publish(topic, msg, 0, 0, function(client) print(msg) end)
            end,
            botao2 = function(l, t)
                print(">->->")
                consts.x = (consts.x) % 7 + 1
                print("x=" .. consts.x)
                msg = meuid .. ",BROADCAST," .. consts.sala .. ",MOV," .. consts.x
                consts.m:publish(topic, msg, 0, 0, function(client) print(msg) end)
            end,
            botao4 = function(l, t)
                gpio.write(led1, gpio.HIGH);
                gpio.write(led2, gpio.LOW);
                if matriz.dropPiece(1, consts.x) then
                    print("OK")
                    matriz.imprime()

                    msg = meuid .. ",BROADCAST," .. consts.sala .. ",OK," .. consts.x
                    consts.m:publish(topic, msg, 0, 0, function(client) print(msg) end)
                    consts.estado = "jogo2"
                    -- local verifica = dofile("verifica.lua")
                    if matriz.verifica() == 1 then
                        print("VOCE VENCEU!")
                        gpio.write(led1, gpio.HIGH);
                        gpio.write(led2, gpio.HIGH);
                        local win = {{233,200}, {294,200}, {349,200}, {440,200}, {587,200}, {932,500}, {932,200}, {932,200}, {932,200}, {1047,1000}}
                        beep(win)
                        consts.estado = "final"
                    end
                else
                    print("Jogada invalida")
                end
            end,
            message = function(client, topic, message)
                tmsg = mysplit(message, ",")
                if tmsg[1] == meuid then
                    return
                    -- elseif tmsg[2] == "SUB" then
                    --   msg = meuid .. ",JOG"
                    --   consts.m:publish(topic, msg, 0, 0, function(client) print(msg) end)
                    -- elseif tmsg[2] == "JOG" then
                    --   gpio.write(led1, gpio.HIGH);
                    --   gpio.write(led2, gpio.LOW);
                    --   consts.estado = "jogo2"
                end
            end
        },
        jogo2 = {
            message = function(client, topic, message)
                tmsg = mysplit(message, ",")
                if tmsg[1] == meuid then
                    return
                elseif tmsg[2] == "BROADCAST" and tmsg[3] == consts.sala and tmsg[4] == "OK" then
                    -- node_id,BROADCAST,salax,OK,valor
                    print(message)
                    consts.x = tonumber(tmsg[5])
                    matriz.dropPiece(2, consts.x)
                    matriz.imprime()
                    gpio.write(led1, gpio.LOW)
                    gpio.write(led2, gpio.HIGH)
                    consts.estado = "jogo1"

                    -- local verifica = dofile("verifica.lua")
                    if matriz.verifica() == 2 then
                        print("VOCE PERDEU!")
                        gpio.write(led1, gpio.HIGH)
                        gpio.write(led2, gpio.HIGH)
                        beep({{392,250},{262,500}})
                        consts.estado = "final"
                    end
                end
            end
        }

    }
    return maquina
end

return { criaMaquina = criaMaquina }

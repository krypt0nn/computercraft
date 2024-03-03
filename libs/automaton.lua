function info()
    return {
        version = 1,
        rednet = {
            protocol = "new_london/automaton"
        }
    }
end

local backgroundTask = coroutine.create(function()
    while true do
        senderId, message, _ = rednet.receive(info().rednet.protocol)

        if info().version >= message.version then
            if message.packet == "ping" then
                rednet.send(senderId, {
                    packet = "pong",
                    version = info().version
                }, info().rednet.protocol)
            end
        end
    end
end)

Automaton = {}

function Automaton:connect(id)
    rednet.send(id, {
        packet  = "ping",
        version = info().version
    }, info().rednet.protocol)

    fromId, message, _ = rednet.receive(info().rednet.protocol, 5)

    -- Check returned information
    if fromId ~= id then
        return nil
    end

    -- Check packet type
    if message.packet ~= "pong" then
        return nil
    end

    -- Check protocols compatibility
    if info().version < message.version then
        return nil
    end

    return setmetatable({
        id = id
    }, {
        _index = Automaton
    })
end

function Automaton:current()

end

return {
    info = info,
    Automaton = Automaton
}

local function info()
    return {
        version = 4,
        rednet = {
            protocol = "new_london/notifications"
        }
    }
end

local function send(id, message)
    return rednet.send(id, {
        version = info().version,
        packet  = "notification",
        sender  = os.computerLabel(),
        message = message
    }, info().rednet.protocol)
end

local function broadcast(message)
    return rednet.broadcast({
        version = info().version,
        packet  = "broadcast",
        sender  = os.computerLabel(),
        message = message
    }, info().rednet.protocol)
end

local function backgroundTask()
    while true do
        senderId, message, _ = rednet.receive(info().rednet.protocol)

        if info().version >= message.version then
            if message.packet == "notification" then
                print("[notif] <" .. message.sender .. ">: " .. message.message)
            elseif message.packet == "broadcast" then
                print("[broad] <" .. message.sender .. ">: " .. message.message)
            end
        end
    end
end

return {
    info      = info,
    send      = send,
    broadcast = broadcast,
    backgroundTask = backgroundTask
}

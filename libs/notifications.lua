-- notifications.lua
-- Copyright (c) 2024-2025 Nikita Podvirnyi
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.

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

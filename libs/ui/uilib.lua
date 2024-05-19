local function info()
    return {
        version = 4
    }
end

local layers = {}

-- Check if given name belongs to a monitor
local function isMonitor(name)
    local monitor = peripheral.wrap(ui)

    if not monitor then
        return false
    end

    return monitor.getSize and monitor.setCursorPos and monitor.blit
end

local function fillRectangle(x, y, w, h, color, monitor)
    monitor.setBackgroundColor(color)

    for i = y, y + h do
        monitor.setCursorPos(x, i)
        monitor.write(string.rep(" ", w))
    end
end

-- Default widget params
local Widget = {
    parent = nil,

    padding = {
        left   = 1,
        top    = 1,
        right  = 1,
        bottom = 1
    },

    margin = {
        left   = 0,
        top    = 0,
        right  = 0,
        bottom = 0
    },

    rounding = {
        radius = 0,
        resolution = 15
    }
}

-- Create new widget
function Widget:new(parent)
    local widget = {
        parent = parent
    }

    return setmetatable(widget, {
        __index = Widget
    })
end

-- Get widget's monitor
function Widget:getMonitor()
    -- If no parent given - try to find a monitor and use it
    if self.parent == nil then
        local monitor = peripheral.find("monitor")

        if not monitor then
            error("Can't get widget monitor: no parent or monitor found")
        end

        return monitor

    -- If parent is a string - try to use it as a monitor name
    elseif type(self.parent) == "string" then
        local monitor = peripheral.wrap(self.parent)

        if not monitor then
            error("Can't get widget monitor: wrong monitor name")
        end

        return monitor

    -- If parent is table - use it as a widget
    elseif type(self.parent) == "table" then
        return self:getMonitor()

    -- Otherwise we don't know what this is
    else
        error("Can't get widget monitor: wrong parent type")
    end
end

-- Get widget size, respecting its margin
function Widget:getSize()
    local width, height, x, y

    -- If no parent given - try to find a monitor and use it
    if self.parent == nil then
        local monitor = peripheral.find("monitor")

        if not monitor then
            error("Can't get widget size: no parent or monitor found")
        end

        width, height = monitor.getSize()

        x = 0
        y = 0

    -- If parent is a string - try to use it as a monitor name
    elseif type(self.parent) == "string" then
        local monitor = peripheral.wrap(self.parent)

        if not monitor then
            error("Can't get widget size: wrong monitor name")
        end

        width, height = monitor.getSize()

        x = 0
        y = 0

    -- If parent is table - use it as a widget
    elseif type(self.parent) == "table" then
        width, height, x, y = self.parent.getSize()

        x = x + self.parent.padding.left
        y = y + self.parent.padding.top

    -- Otherwise we don't know what this is
    else
        error("Can't get widget size: wrong parent type")
    end

    width  = width  - self.margin.left - self.margin.right
    height = height - self.margin.top  - self.margin.bottom

    x = x + self.margin.left
    y = y + self.margin.top

    return {
        x = x,
        y = y,
        width = math.max(width, 0),
        height = math.max(height, 0)
    }
end

-- Get size of the widget's content space
function Widget:getContentSize()
    local sizes = self:getSize()

    local width  = sizes.width  - self.padding.left - self.padding.right
    local height = sizes.height - self.padding.top  - self.padding.bottom

    local x = sizes.x + self.padding.left
    local y = sizes.y + self.padding.top

    return {
        x = x,
        y = y,
        width = math.max(width, 0),
        height = math.max(height, 0)
    }
end

-- Get widget rounding
function Widget:getRounding()
    if type(self.rounding.radius) == "number" then
        return {
            vertical = self.rounding.radius,
            horizontal = math.floor(self.rounding.radius * 1.5 + 0.5),
            resolution = self.rounding.resolution or 15
        }

    elseif type(self.rounding.radius) == "table" then
        return {
            vertical = self.rounding.radius.vertical or 0,
            horizontal = self.rounding.radius.horizontal or 0,
            resolution = self.rounding.resolution or 15
        }

    else
        return {
            vertical = 0,
            horizontal = 0,
            resolution = 15
        }
    end
end

function Widget:fill(backgroundColor)
    local sizes    = self:getSize()
    local monitor  = self:getMonitor()
    local rounding = self:getRounding()

    -- Rounding
    if rounding.vertical > 0 or rounding.horizontal > 0 then
        -- Left top corner
        local circle_x = sizes.x + sizes.horizontal
        local circle_y = sizes.y + sizes.vertical

        for angle = 90, 180, resolution do
            local curve_x = circle_x - sizes.horizontal * math.cos(math.rad(angle))
            local curve_y = circle_y - sizes.vertical * math.cos(math.rad(angle))

            fillRectangle(curve_x, curve_y, circle_x - curve_x, 1, backgroundColor, monitor)
        end

        -- Right top corner
        local circle_x = sizes.x + sizes.width - sizes.horizontal
        local circle_y = sizes.y + sizes.vertical

        for angle = 0, 90, resolution do
            local curve_x = circle_x - sizes.horizontal * math.cos(math.rad(angle))
            local curve_y = circle_y - sizes.vertical * math.cos(math.rad(angle))

            fillRectangle(circle_x, curve_y, curve_x - circle_x, 1, backgroundColor, monitor)
        end

        -- Left bottom corner
        local circle_x = sizes.x + sizes.horizontal
        local circle_y = sizes.y + sizes.height - sizes.vertical

        for angle = 180, 270, resolution do
            local curve_x = circle_x - sizes.horizontal * math.cos(math.rad(angle))
            local curve_y = circle_y - sizes.vertical * math.cos(math.rad(angle))

            fillRectangle(curve_x, curve_y, circle_x - curve_x, 1, backgroundColor, monitor)
        end

        -- Right bottom corner
        local circle_x = sizes.x + sizes.width  - sizes.horizontal
        local circle_y = sizes.y + sizes.height - sizes.vertical

        for angle = 270, 360, resolution do
            local curve_x = circle_x - sizes.horizontal * math.cos(math.rad(angle))
            local curve_y = circle_y - sizes.vertical * math.cos(math.rad(angle))

            fillRectangle(circle_x, curve_y, curve_x - circle_x, 1, backgroundColor, monitor)
        end

        -- Top-bottom fill
        fillRectangle(sizes.x + sizes.horizontal, sizes.y, sizes.width - sizes.horizontal * 2, sizes.height, backgroundColor, monitor)

        -- Left-right fill
        fillRectangle(sizes.x, sizes.y + sizes.vertical, sizes.width, sizes.height - sizes.vertical * 2, backgroundColor, monitor)
    else
        fillRectangle(sizes.x, sizes.y, sizes.width, sizes.height, backgroundColor, monitor)
    end
end

-- Start rendering given UI
local function render(ui)
    if not isMonitor(ui.monitor) then
        error("Invalid monitor name: [" .. ui.monitor .. "]")
    end

    error("TBD")
end

return {
    info = info,
    isMonitor = isMonitor,
    fillRectangle = fillRectangle,
    Widget = Widget,
    render = render
}

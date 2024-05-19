local function info()
    return {
        version = 2
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

    return math.max(width, 0), math.max(height, 0), x, y
end

-- Get size of the widget's content space
function Widget:getContentSize()
    local width, height, x, y = self:getSize()

    width  = width  - self.padding.left - self.padding.right
    height = height - self.padding.top  - self.padding.bottom

    x = x + self.padding.left
    y = y + self.padding.top

    return math.max(width, 0), math.max(height, 0), x, y
end

function Widget:fill(backgroundColor)
    local width, height, x, y = self:getSize()
    local monitor = self:getMonitor()

    local radius     = self.rounding.radius or 0
    local resolution = self.rounding.resolution or 15

    -- Rounding
    if radius > 0 then
        -- Left top corner
        local circle_x = x + radius
        local circle_y = y + radius

        for angle = 90, 180, resolution do
            local curve_x = circle_x - radius * math.cos(math.rad(angle))
            local curve_y = circle_y - radius * math.cos(math.rad(angle))

            fillRectangle(curve_x, curve_y, circle_x - curve_x, 1, backgroundColor, monitor)
        end

        -- Right top corner
        local circle_x = x + width - radius
        local circle_y = y         + radius

        for angle = 0, 90, resolution do
            local curve_x = circle_x - radius * math.cos(math.rad(angle))
            local curve_y = circle_y - radius * math.cos(math.rad(angle))

            fillRectangle(circle_x, curve_y, curve_x - circle_x, 1, backgroundColor, monitor)
        end

        -- Left bottom corner
        local circle_x = x          + radius
        local circle_y = y + height - radius

        for angle = 180, 270, resolution do
            local curve_x = circle_x - radius * math.cos(math.rad(angle))
            local curve_y = circle_y - radius * math.cos(math.rad(angle))

            fillRectangle(curve_x, curve_y, circle_x - curve_x, 1, backgroundColor, monitor)
        end

        -- Right bottom corner
        local circle_x = x + width  - radius
        local circle_y = y + height - radius

        for angle = 270, 360, resolution do
            local curve_x = circle_x - radius * math.cos(math.rad(angle))
            local curve_y = circle_y - radius * math.cos(math.rad(angle))

            fillRectangle(circle_x, curve_y, curve_x - circle_x, 1, backgroundColor, monitor)
        end

        -- Top-bottom fill
        fillRectangle(x + radius, y, width - radius * 2, height, backgroundColor, monitor)

        -- Left-right fill
        fillRectangle(x, y + radius, width, height - radius * 2, backgroundColor, monitor)
    else
        fillRectangle(x, y, width, height, backgroundColor, monitor)
    end
end

local function fillRectangle(x, y, w, h, color, monitor)
    monitor.setBackgroundColor(color)

    for i = y, y + h do
        monitor.setCursorPos(x, i)
        monitor.write(string.rep(" ", w))
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

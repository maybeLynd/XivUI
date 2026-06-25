
local images = require('images')

local classes = require('components/xivparty/classes')
local uiElement = require('components/xivparty/uielement')
local utils = require('components/xivparty/utils')
local const = require('components/xivparty/const')

local uiImage = classes.class(uiElement)

local private = {}

function uiImage.create(path, sizeX, sizeY, posX, posY, scaleX, scaleY)
    if not sizeX then
        sizeX = 0
        sizeY = 0
    end
    if not posX then
        posX = 0
        posY = 0
    end
    if not scaleX then
        scaleX = 1
        scaleY = 1
    end

    local imageLayout = {}
    imageLayout.enabled = true
    imageLayout.path = path
    imageLayout.size = L{ sizeX, sizeY }
    imageLayout.pos = L{ posX, posY }
    imageLayout.scale = L{ scaleX, scaleY }

    return uiImage.new(imageLayout)
end

function uiImage:init(layout)
    if self.super:init(layout) then
        private[self] = {}

        if layout and layout.path and layout.path ~= '' then
            private[self].path = layout.path
        end

        self.width = 0
        self.height = 0
        if layout and layout.size then
            local size = utils:coord(layout.size)
            self.width = size.x
            self.height = size.y
        end

        self.absoluteWidth = 0
        self.absoluteHeight = 0

        private[self].color = {}
        private[self].color.r = 255
        private[self].color.g = 255
        private[self].color.b = 255
        private[self].color.a = 255
        if layout and layout.color then
            local c = utils:colorFromHex(layout.color)
            if c then
                private[self].color = c
            end
        end

        private[self].opacity = 1.0
        private[self].initFrames = -1
        private[self].initShown = false
    end
end

function uiImage:dispose()
    if not self.isEnabled then return end

    if self.isCreated then
        images.destroy(self.wrappedImage)
        RefCountImage = RefCountImage - 1
    end
    private[self] = nil

    self.super:dispose()
end

local function setPath(image, path)
    image.wrappedImage:path(windower.addon_path .. path)

    if not path or path == '' then
        private[image].initShown = false
    elseif not private[image].initShown then
        image:hide(const.visInit)
        private[image].initFrames = 2
    end
end

function uiImage:createPrimitives()
    if not self.isEnabled or self.isCreated then return end

    self.wrappedImage = images.new()
    RefCountImage = RefCountImage + 1
    self.wrappedImage:draggable(false)
    self.wrappedImage:fit(false)

    self.wrappedImage:repeat_xy(private[self].repeatX, private[self].repeatY)
    self.wrappedImage:color(private[self].color.r, private[self].color.g, private[self].color.b)
    self.wrappedImage:alpha(private[self].color.a * private[self].opacity)

    if private[self].path then
        setPath(self, private[self].path)
    end

    self.super:createPrimitives()
end

function uiImage:updateLayout()
    if not self.isEnabled then return end

    self.super:updateLayout()

    self.absoluteWidth = self.width * self.absoluteScale.x
    self.absoluteHeight = self.height * self.absoluteScale.y
end

function uiImage:update()
    if not self.isEnabled then return end

    if private[self].initFrames >= 0 then
        if private[self].initFrames == 0 then
            self:show(const.visInit)
            private[self].initShown = true
        end
        private[self].initFrames = private[self].initFrames - 1
    end
end

function uiImage:applyLayout()
    if not self.isEnabled then return end

    if self.isCreated then
        self.wrappedImage:pos(self.absolutePos.x, self.absolutePos.y)
        self.wrappedImage:size(self.absoluteWidth, self.absoluteHeight)
        self.wrappedImage:visible(self.absoluteVisibility)
    end
end

function uiImage:path(path)
    if not self.isEnabled then return end

    if private[self].path ~= path then
        private[self].path = path

        if self.isCreated then
            setPath(self, private[self].path)
        end
    end
end

function uiImage:size(w, h)
    if not self.isEnabled then return end

    if self.width ~= w or self.height ~= h then
        self.width = w;
        self.height = h;

        self:layoutElement()
    end
end

function uiImage:repeat_xy(x, y)
    if not self.isEnabled then return end

    if private[self].repeatX ~= x or private[self].repeatY ~= y then
        private[self].repeatX = x
        private[self].repeatY = y

        if self.isCreated then
            self.wrappedImage:repeat_xy(x, y)
        end
    end
end

function uiImage:hover(x ,y)
    if not self.isEnabled or not self.isCreated then return false end

    return self.wrappedImage:hover(x, y)
end

function uiImage:color(r, g, b)
    if not self.isEnabled then return end
    if r == nil then utils:log('uiImage:color missing parameter r!', 4) return end

    local a = nil

    if type(r) == 'table' and r.r and r.g and r.b and r.a then
        a = r.a
        b = r.b
        g = r.g
        r = r.r
    end

    if private[self].color.r ~= r or private[self].color.g ~= g or private[self].color.b ~= b then
        private[self].color.r = r
        private[self].color.g = g
        private[self].color.b = b

        if self.isCreated then
            self.wrappedImage:color(r, g, b)
        end
    end

    if a then
        self:alpha(a)
    end
end

function uiImage:alpha(a)
    if not self.isEnabled then return end
    if a == nil then utils:log('uiImage:alpha missing parameter a!', 4) return end

    if private[self].color.a ~= a then
        private[self].color.a = a

        if self.isCreated then
            self.wrappedImage:alpha(private[self].color.a * private[self].opacity)
        end
    end
end

function uiImage:opacity(o)
    if not self.isEnabled then return end
    if o == nil then utils:log('uiImage:opacity missing parameter o!', 4) return end

    if private[self].opacity ~= o then
        private[self].opacity = o

        if self.isCreated then
            self.wrappedImage:alpha(private[self].color.a * private[self].opacity)
        end
    end
end

return uiImage

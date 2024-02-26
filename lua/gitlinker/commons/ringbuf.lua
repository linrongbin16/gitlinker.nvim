local M = {}

--- @class commons.RingBuffer
--- @field pos integer
--- @field queue any[]
--- @field size integer
--- @field maxsize integer
local RingBuffer = {}

--- @param maxsize integer?
--- @return commons.RingBuffer
function RingBuffer:new(maxsize)
  assert(type(maxsize) == "number" and maxsize > 0)
  local o = {
    pos = 0,
    queue = {},
    size = 0,
    maxsize = maxsize,
  }
  setmetatable(o, self)
  self.__index = self
  return o
end

--- @param idx integer
--- @return integer
function RingBuffer:_inc(idx)
  if idx == self.maxsize then
    return 1
  else
    return idx + 1
  end
end

--- @param idx integer
--- @return integer
function RingBuffer:_dec(idx)
  if idx == 1 then
    return self.maxsize
  else
    return idx - 1
  end
end

--- @param item any
--- @return integer
function RingBuffer:push(item)
  assert(self.size >= 0 and self.size <= self.maxsize)

  if self.size < self.maxsize then
    table.insert(self.queue, item)
    self.pos = self:_inc(self.pos)
    self.size = self.size + 1
  else
    self.pos = self:_inc(self.pos)
    self.queue[self.pos] = item
  end
  return self.pos
end

--- @return any?
function RingBuffer:pop()
  if self.size <= 0 then
    return nil
  end

  local old = self.queue[self.pos]
  self.queue[self.pos] = nil
  self.size = self.size - 1
  self.pos = self:_dec(self.pos)
  return old
end

--- @return any?
function RingBuffer:peek()
  if self.size <= 0 then
    return nil
  end
  return self.queue[self.pos]
end

--- @return integer
function RingBuffer:clear()
  local old = self.size
  self.pos = 0
  self.queue = {}
  self.size = 0
  return old
end

-- RingBufferIterator {

-- usage:
--
-- ```lua
-- local it = ringbuf:iterator()
-- local item = nil
-- repeat
--   item = it:next()
--   if item then
--     -- consume item data
--   end
-- until item
-- ```
--
--- @class commons._RingBufferIterator
--- @field ringbuf commons.RingBuffer
--- @field index integer
--- @field initial_index integer
local _RingBufferIterator = {}

--- @param ringbuf commons.RingBuffer
--- @param index integer
--- @return commons._RingBufferIterator
function _RingBufferIterator:new(ringbuf, index)
  assert(type(ringbuf) == "table")

  local o = {
    ringbuf = ringbuf,
    index = index,
    initial_index = index,
  }
  setmetatable(o, self)
  self.__index = self
  return o
end

--- @return boolean
function _RingBufferIterator:has_next()
  if self.ringbuf.size == 0 then
    return false
  end
  if self.index <= 0 or self.index > self.ringbuf.size then
    return false
  end
  if self.index ~= self.initial_index and self.ringbuf:_inc(self.index) == self.initial_index then
    return false
  end

  return true
end

--- @return any?
function _RingBufferIterator:next()
  assert(self:has_next())
  assert(self.index >= 1 and self.index <= self.ringbuf.maxsize)
  local item = self.ringbuf.queue[self.index]
  self.index = self.ringbuf:_inc(self.index)
  return item
end

-- RingBufferIterator }

-- RingBufferRIterator {

--- @class commons._RingBufferRIterator
--- @field ringbuf commons.RingBuffer
--- @field index integer
--- @field initial_index integer
local _RingBufferRIterator = {}

--- @param ringbuf commons.RingBuffer
--- @param index integer
--- @return commons._RingBufferRIterator
function _RingBufferRIterator:new(ringbuf, index)
  assert(type(ringbuf) == "table")

  local o = {
    ringbuf = ringbuf,
    index = index,
    initial_index = index,
  }
  setmetatable(o, self)
  self.__index = self
  return o
end

--- @return boolean
function _RingBufferRIterator:has_next()
  if self.ringbuf.size == 0 then
    return false
  end
  if self.index <= 0 or self.index > self.ringbuf.size then
    return false
  end
  if self.index ~= self.initial_index and self.ringbuf:_dec(self.index) == self.initial_index then
    return false
  end

  return true
end

--- @return any?
function _RingBufferRIterator:next()
  assert(self:has_next())
  assert(self.index >= 1 and self.index <= self.ringbuf.maxsize)

  local item = self.ringbuf.queue[self.index]
  self.index = self.ringbuf:_dec(self.index)
  return item
end

-- RingBufferRIterator }

--- @return commons._RingBufferIterator
function RingBuffer:iterator()
  if self.size < self.maxsize then
    return _RingBufferIterator:new(self, 0)
  else
    return _RingBufferIterator:new(self, self:_inc(self.pos))
  end
end

--- @return commons._RingBufferRIterator
function RingBuffer:riterator()
  return _RingBufferRIterator:new(self, self.pos)
end

M.RingBuffer = RingBuffer

return M

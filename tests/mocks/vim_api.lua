-- tests/mocks/vim_api.lua
-- Mock for vim global object and its relevant submodules/functions
local spy = require('luassert.spy')

local M = {
  api = {
    nvim_paste = spy.new(function() end),
    -- Add other vim.api functions if needed by the code under test
  },
  keymap = {
    set = spy.new(function() end),
  },
  -- Simple immediate execution mock for vim.schedule
  schedule = function(callback)
    callback()
  end,
  -- Use real json encode/decode unless specific mocking is needed
  json = {
    encode = vim.json.encode,
    decode = vim.json.decode,
  },
  -- Mock other vim.* elements if the code uses them (e.g., fn, loop, bo)
  fn = {},
  loop = {},
  bo = setmetatable({}, { -- Mock buffer options if needed
    __index = function(_, key)
      print("Accessed mock vim.bo." .. key)
      return nil
    end,
  }),
  inspect = vim.inspect, -- Use real inspect
}

-- Function to reset all spies within the mock
function M.reset()
  if M.api.nvim_paste.reset then M.api.nvim_paste:reset() end
  if M.keymap.set.reset then M.keymap.set:reset() end
  -- Reset other spies if added
end

-- Replace the global vim object with this mock during tests
-- This is typically done in the test file's setup/before_each
-- _G.vim = M

return M


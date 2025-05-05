local curl = require('plenary.curl')
local nui_input = require("nui.input")
local nui_utils_event = require("nui.utils.autocmd").event

local mlflow_uri

local function telescope_input(prompt, callback)
  local input_box = nui_input({
    position = "50%",
    size = {
      width = 40,
    },
    border = {
      style = "rounded",
      text = {
        top = prompt,
        top_align = "center",
      },
    },
    win_options = {
      winhighlight = "Normal:Normal,FloatBorder:FloatBorder",
    },
  }, {
    prompt = "",
    on_submit = callback,
  })

  input_box:mount()

  input_box:on(nui_utils_event.BufLeave, function()
    input_box:unmount()
  end)
end


---@class AsyncHttpRequestOpts
---@field url string
---@field method string
---@field body string?
---@field headers table?
---@field callback function

---@param opts AsyncHttpRequestOpts
local function async_http_request(opts)
  curl.request({
    url = opts.url,
    method = opts.method,
    headers = opts.headers,
    body = opts.body,
    on_success = function(res)
      -- plenary curl returns the body directly
      opts.callback(res.body)
    end,
    on_error = function(err)
      print("HTTP Request Error: " .. vim.inspect(err))
    end,
  })
end

local function fetch_run_metrics(run_id, callback)
  local method = 'GET'
  local url = mlflow_uri .. '/api/2.0/mlflow/runs/get?run_id=' .. run_id
  -- local headers = { ['Content-Type'] = 'application/json' }
  -- local body = {
  --   max_results = 1
  -- }
  async_http_request({
    url = url,
    method = method,
    callback = function(data)
      local run_data = vim.json.decode(data)
      callback(run_data)
    end
  })
end

local function paste_run_metrics(data)
  vim.schedule(function()
    vim.api.nvim_paste(vim.json.encode(data), true, -1)
  end)
end

local function bring_run_metrics()
  telescope_input(
    'Enter run id',
    function(run_id)
      fetch_run_metrics(run_id, paste_run_metrics)
    end
  )
end

local function setup(opts)
  mlflow_uri = opts.mlflow_uri or os.getenv('MLFLOW_URI')
  vim.keymap.set('n', '<leader>tml', bring_run_metrics, { desc = 'Mlflow run' })
end

return { setup = setup }

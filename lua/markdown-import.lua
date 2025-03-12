local mlflow_uri
local nui_input = require("nui.input")
local nui_utils_event = require("nui.utils.autocmd").event

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


---@param url string
---@param method string
---@param body string
---@param headers table
---@param callback function
local function async_http_request(opts)
  local uv = require('luv')
  local stdout = uv.new_pipe(false)
  local stderr = uv.new_pipe(false)
  local handle

  local args = { "-s", "-X", opts.method, opts.url }
  if opts.headers then
    for _, header in ipairs(opts.headers) do
      table.insert(args, "-H")
      table.insert(args, header)
    end
  end

  if opts.body and opts.body ~= "" then
    table.insert(args, "-d")
    table.insert(args, "'" .. opts.body .. "'")
  end

  handle = uv.spawn(
    "curl",
    {
      args = args,
      stdio = { nil, stdout, stderr }
    },
    function(code, signal)
      stdout:close()
      stderr:close()
      handle:close()
    end
  )

  uv.read_start(stdout, function(err, data)
    if err then
      print("Error: " .. err)
      return
    end
    if data then
      opts.callback(data)
    end
  end)

  vim.loop.read_start(stderr, function(err, data)
    if err then
      print("Curl Error: " .. err)
    elseif data then
      print("Curl Stderr: " .. data)
    end
  end)
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
  vim.keymap.set('n', '<leader>tml', bring_run_metrics, {desc='Mlflow run'})
end

return { setup = setup }

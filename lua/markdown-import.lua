local curl = require('plenary.curl')
local nui_input = require("nui.input")
local nui_utils_event = require("nui.utils.autocmd").event

local mlflow_uri
local databricks_token
local databricks_host

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
  local headers = opts.headers or {}
  -- Add Databricks authentication if configured
  if databricks_token then
    headers['Authorization'] = 'Bearer ' .. databricks_token
  end

  curl.request({
    url = opts.url,
    method = opts.method,
    headers = headers,
    body = opts.body,
    callback = function(res)
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
  async_http_request({
    url = url,
    method = method,
    callback = function(data)
      local run_data = vim.json.decode(data)
      local run_uri
      if os.getenv('MLFLOW_TRACKING_URI') == "databricks" then
        run_uri = mlflow_uri .. '/ml/experiments/' .. run_data.run.info.experiment_id .. '/runs/' .. run_data.run.info.run_id
      else
        run_uri = mlflow_uri .. '/#/experiments/' .. run_data.run.info.experiment_id .. '/runs/' .. run_data.run.info.run_id
      end
      callback(run_uri, run_data)
    end
  })
end

local function paste_run_metrics(run_uri, data)
  print("run_uri:" .. run_uri)
  vim.schedule(function()
    -- print keys of data
    local keys = {}
    for _, v in pairs(data.run.data.metrics) do
      table.insert(keys, v)
    end
    vim.api.nvim_paste("run name: [" .. data.run.info.run_name .. "](" .. run_uri ..")\n", true, -1)
    for _, elem in pairs(keys) do
      local metric_name = elem.key
      local metric_value = elem.value

      -- convert value to float with two decimal places
      local metric_value_float = string.format("%.4f", metric_value)

      vim.api.nvim_paste("- " .. metric_name .. ": " .. metric_value_float .. "\n", true, -1)
    end
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
  mlflow_uri = os.getenv('MLFLOW_TRACKING_URI') or opts.mlflow_uri

  -- Handle Databricks configuration
  if mlflow_uri == "databricks" then
    databricks_host = os.getenv('DATABRICKS_HOST')
    databricks_token = os.getenv('DATABRICKS_TOKEN')
    if not databricks_host or not databricks_token then
      error("When using Databricks MLflow, both DATABRICKS_HOST and DATABRICKS_TOKEN environment variables are required")
    end
    mlflow_uri = databricks_host
  end

  vim.keymap.set('n', '<leader>tml', bring_run_metrics, { desc = 'Mlflow run' })
end

return { setup = setup }

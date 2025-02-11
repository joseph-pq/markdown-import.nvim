local mlflow_uri

local function async_http_request(url, method, body, headers, callback)
  local uv = require('luv')
  local stdout = uv.new_pipe(false)
  local stderr = uv.new_pipe(false)
  local handle

  local args = { "-s", "-X", method, url }
  if headers then
      for _, header in ipairs(headers) do
          print("header: " .. header)
          table.insert(args, "-H")
          table.insert(args, header)
      end
  end

  if body and body ~= "" then
    table.insert(args, "-d")
    table.insert(args, "'" .. body .. "'")
  end
  print("curl " .. table.concat(args, " "))

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
      callback(data)
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

local function fetch_mlflow_experiments()
  local method = 'GET'
  local url = mlflow_uri .. '/api/2.0/mlflow/experiments/search'
  local headers = { ['Content-Type'] = 'application/json' }
  local body = {
    max_results = 1
  }
  async_http_request(url, method, vim.json.encode(body), headers, function(data)
    print("gaaaaaa")
    local experiments = vim.json.decode(data)
    print(vim.inspect(experiments))
  end)
end

local function setup(opts)
  mlflow_uri = opts.mlflow_uri
  vim.keymap.set("n", "<leader>tml", fetch_mlflow_experiments)
end

return { setup = setup }

local mlflow_uri

local function fetch_mlflow_experiments()
  print("Listing MLflow experiments from URI: " .. mlflow_uri)
end

local function setup(opts)
  mlflow_uri = opts.mlflow_uri
  vim.keymap.set("n", "<leader>ml", fetch_mlflow_experiments)
end

return { setup = setup }

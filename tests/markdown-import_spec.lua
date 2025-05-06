-- tests/markdown-import_spec.lua
-- Tests for the markdown-import module
-- luacheck: globals describe it before_each after_each spy match assert

describe('markdown-import', function()
  local markdown_import
  local mock_curl
  local mock_nui_input
  local original_vim -- Declare original_vim here

  -- Mock objects
  local mock_vim = {
    api = {
      nvim_paste = function() end,
    },
    keymap = {
      set = function() end,
    },
    schedule = function(callback)
      callback()
    end,
    json = {
      encode = vim.json.encode,
      decode = vim.json.decode,
    },
    inspect = vim.inspect
  }

  before_each(function()
    -- Save the original vim global
    original_vim = _G.vim -- Assign to the outer scope variable

    -- Mock the vim global
    _G.vim = mock_vim

    -- Spy on vim functions
    spy.on(mock_vim.api, 'nvim_paste')
    spy.on(mock_vim.keymap, 'set')

    -- Mock the curl module
    mock_curl = {
      request = spy.new(function(opts)
        -- Simulate an async response
        if opts.url:match('/mlflow/runs/get') then
          local run_id = opts.url:match('run_id=([^&]+)')
          local mock_response = {
            body = vim.json.encode({
              run = {
                info = { run_id = run_id },
                data = {
                  metrics = {
                    { key = 'accuracy', value = 0.95 },
                    { key = 'loss', value = 0.05 },
                  }
                }
              }
            })
          }
          opts.on_success(mock_response)
        end
      end)
    }

    -- Mock the nui.input module
    mock_nui_input = spy.new(function(_, config)
      -- Immediately trigger callback with test data
      vim.schedule(function()
        if config.on_submit then
          config.on_submit('test_run_id')
        end
      end)

      -- Return a mock input object
      return {
        mount = spy.new(function() end),
        unmount = spy.new(function() end),
        on = spy.new(function() end)
      }
    end)

    -- Load the module under test with mocked dependencies
    package.loaded['plenary.curl'] = mock_curl
    package.loaded['nui.input'] = mock_nui_input
    package.loaded['nui.utils.autocmd'] = { event = { BufLeave = 'BufLeave' } }

    package.loaded['markdown-import'] = nil  -- Clear the cache
    markdown_import = require('markdown-import')

    -- Set up the module with test configuration
    markdown_import.setup({
      mlflow_uri = 'http://test-mlflow-server'
    })
  end)

  after_each(function()
    -- Restore the original vim global
    _G.vim = original_vim

    -- Clear mocks
    mock_vim.api.nvim_paste:clear()
    mock_vim.keymap.set:clear()

    -- Clear loaded modules
    package.loaded['plenary.curl'] = nil
    package.loaded['nui.input'] = nil
    package.loaded['nui.utils.autocmd'] = nil
  end)

  describe('setup', function()
    it('should set up keymappings', function()
      assert.spy(mock_vim.keymap.set).was_called()
      assert.spy(mock_vim.keymap.set).was_called_with(
        'n', '<leader>tml', match._, { desc = 'Mlflow run' }
      )
    end)

    it('should use the provided mlflow_uri', function()
      -- This is an internal state check, so we need to test via behavior
      -- Trigger the bring_run_metrics function via mocked nui_input
      local bring_run_metrics = mock_vim.keymap.set.calls[1].vals[3]
      bring_run_metrics()

      -- Check that the curl request was made with the correct URI
      assert.spy(mock_curl.request).was_called()
      assert.spy(mock_curl.request).was_called_with(match.has_match({
        url = 'http://test-mlflow-server/api/2.0/mlflow/runs/get'
      }))
    end)

    it('should fall back to MLFLOW_URI environment variable', function()
      -- Recreate the module with no explicit URI
      package.loaded['markdown-import'] = nil
      mock_vim.keymap.set:clear()
      mock_curl.request:clear()

      -- Mock the environment variable
      local original_getenv = os.getenv
      os.getenv = function(name)
        if name == 'MLFLOW_URI' then
          return 'http://env-mlflow-server'
        end
        return original_getenv(name)
      end

      -- Reload and setup
      markdown_import = require('markdown-import')
      markdown_import.setup({})

      -- Test the behavior
      local bring_run_metrics = mock_vim.keymap.set.calls[1].vals[3]
      bring_run_metrics()

      -- Check URI
      assert.spy(mock_curl.request).was_called_with(match.has_match({
        url = 'http://env-mlflow-server/api/2.0/mlflow/runs/get'
      }))

      -- Restore
      os.getenv = original_getenv
    end)
  end)

  describe('bring_run_metrics', function()
    it('should fetch and paste run metrics when triggered', function()
      -- Get the bring_run_metrics function from the keymap
      local bring_run_metrics = mock_vim.keymap.set.calls[1].vals[3]

      -- Clear previous calls
      mock_curl.request:clear()
      mock_vim.api.nvim_paste:clear()

      -- Call the function
      bring_run_metrics()

      -- Check that nui_input was called
      assert.spy(mock_nui_input).was_called()

      -- Check curl request
      assert.spy(mock_curl.request).was_called()
      assert.spy(mock_curl.request).was_called_with(match.has_match({
        url = 'http://test-mlflow-server/api/2.0/mlflow/runs/get?run_id=test_run_id'
      }))

      -- Check that nvim_paste was called with the mock data
      assert.spy(mock_vim.api.nvim_paste).was_called()
      local paste_arg = mock_vim.api.nvim_paste.calls[1].vals[1]
      local decoded = vim.json.decode(paste_arg)

      -- Verify content
      assert.is_not_nil(decoded.run)
      assert.is_not_nil(decoded.run.info)
      assert.is_not_nil(decoded.run.data)
      assert.is_not_nil(decoded.run.data.metrics)
      assert.equals('test_run_id', decoded.run.info.run_id)
      assert.equals(0.95, decoded.run.data.metrics[1].value)
    end)
  end)

  -- Add more test cases for edge cases and other functions

  -- Example: Test error handling
  describe('error handling', function()
    it('should handle HTTP errors gracefully', function()
      -- Replace request with one that triggers the error callback
      mock_curl.request = spy.new(function(opts)
        opts.on_error({ code = 404, message = "Not Found" })
      end)

      -- Spy on print to check error messages
      spy.on(print)

      -- Get and call the function
      local bring_run_metrics = mock_vim.keymap.set.calls[1].vals[3]
      bring_run_metrics()

      -- Verify error was logged
      assert.spy(print).was_called()
      assert.spy(print).was_called_with(match.matches("HTTP Request Error:"))
    end)
  end)

end)


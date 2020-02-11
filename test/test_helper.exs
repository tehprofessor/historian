config_path = __DIR__
filename = ".historian-db-test.ets"
_ = Application.put_env(:historian, :archive_filename, filename)
_ = Application.put_env(:historian, :config_path, config_path)

ExUnit.start()

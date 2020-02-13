use Mix.Config

config :historian,
       archive_filename: ".historian-db-test.ets",
       archive_table_name: :historian_archive_test_db,
       config_path: Path.expand("./test")

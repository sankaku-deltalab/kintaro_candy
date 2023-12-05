import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :kintaro_candy, KinWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "pjzYaHaNa51ts6xgZmgbXi/OydW0/okF1QXBPkDl3gVRU4JG7Iy3mF2uOFGBHF/q",
  server: false

# In test we don't send emails.
config :kintaro_candy, Kin.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters.
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

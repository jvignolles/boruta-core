# Since configuration is shared in umbrella projects, this file
# should only configure the :boruta application itself
# and only for organization purposes. All other config goes to
# the umbrella root.
use Mix.Config

config :boruta, Boruta.Repo,
  ssl: true,
  url: System.get_env("DATABASE_URL"),
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")

config :boruta, Boruta.Oauth,
  expires_in: %{
    access_token: 24 * 3600,
    authorization_code: 60
  },
  secret_key_base: System.get_env("SECRET_KEY_BASE")

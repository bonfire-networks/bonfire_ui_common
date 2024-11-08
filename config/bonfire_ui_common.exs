import Config

config :bonfire_common,
  localisation_path: "priv/localisation"

config :bonfire_ui_common,
  otp_app: :bonfire_ui_common,
  default_web_namespace: Bonfire.UI.Common

config :phoenix, :json_library, Jason

import Config

config :bonfire_ui_common,
  otp_app: :bonfire,
  localisation_path: "priv/localisation",
  default_web_namespace: Bonfire.UI.Common

config :phoenix, :json_library, Jason

defmodule Vik.Presence do
  use Phoenix.Presence,
    otp_app: :vik,
    pubsub_server: Vik.PubSub
end

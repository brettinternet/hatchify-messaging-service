defmodule Messaging.Integrations.Provider do
  @moduledoc """
  Send messages through third-party providers.
  """

  alias Messaging.Conversations.Message

  @doc "Sends message with provider"
  @callback send_message(Message.t()) :: {:ok, map()} | {:error, :provider_error}
end

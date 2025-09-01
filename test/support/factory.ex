defmodule Messaging.Factory do
  @moduledoc false

  # credo:disable-for-this-file Credo.Check.Refactor.LongQuoteBlocks

  defmacro __using__(_opts) do
    quote location: :keep do
      use ExMachina.Ecto, repo: Messaging.Repo

      alias Messaging.Clients.Client
      alias Messaging.Conversation
      alias Messaging.Message
      alias Messaging.Participant
      alias Messaging.Sessions.Session

      @spec conversation_factory(map()) :: Conversation.t()
      def conversation_factory(attrs) do
        %Conversation{
          id: generate_uxid()
        }
        |> merge_attributes(attrs)
        |> evaluate_lazy_attributes()
      end

      @spec message_factory(map()) :: Message.t()
      def message_factory(attrs) do
        %Message{
          id: generate_uxid(),
          conversation_id: generate_uxid(),
          from_address: "+15551234567",
          to_address: "+15557654321",
          message_type: "sms",
          body: "Test message",
          attachments: [],
          provider_id: "test_provider_#{System.unique_integer([:positive])}",
          direction: "inbound",
          timestamp: DateTime.utc_now()
        }
        |> merge_attributes(attrs)
        |> evaluate_lazy_attributes()
      end

      @spec participant_factory(map()) :: Participant.t()
      def participant_factory(attrs) do
        %Participant{
          conversation_id: generate_uxid(),
          participant_address: "+15551234567"
        }
        |> merge_attributes(attrs)
        |> evaluate_lazy_attributes()
      end

      defp generate_uxid do
        16 |> :crypto.strong_rand_bytes() |> Base.encode32(case: :lower, padding: false)
      end
    end
  end
end

defmodule Messaging.Schema do
  @moduledoc false
  defmacro __using__(opts) do
    prefix = Keyword.get(opts, :prefix, "usr")

    quote do
      use Ecto.Schema

      @foreign_key_type :string
      @timestamps_opts [type: :utc_datetime_usec]
      @primary_key {:id, UXID, autogenerate: true, prefix: unquote(prefix), size: :medium}
    end
  end
end

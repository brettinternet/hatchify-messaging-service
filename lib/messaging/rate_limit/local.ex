defmodule Messaging.RateLimit.Local do
  @moduledoc false
  use Hammer, backend: :atomic
end

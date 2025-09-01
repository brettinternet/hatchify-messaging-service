Mimic.copy(Messaging, type_check: true)

ExUnit.start(capture_log: true)
Ecto.Adapters.SQL.Sandbox.mode(Messaging.Repo, :manual)

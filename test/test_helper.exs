ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Mithril.Repo, :manual)
Mox.defmock(Mithril.OTP.SMSMock, for: Mithril.OTP.SMSBehaviour)

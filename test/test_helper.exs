ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Mithril.Repo, :manual)
Mox.defmock(SMSMock, for: Mithril.API.SMSBehaviour)
Mox.defmock(EmailMock, for: Mithril.Registration.EmailBehaviour)

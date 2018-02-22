ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Mithril.Repo, :manual)
Mox.defmock(SMSMock, for: Mithril.OTP.SMSBehaviour)
Mox.defmock(EmailSenderMock, for: Mithril.Registration.EmailBehaviour)

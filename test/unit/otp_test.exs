defmodule Mithril.OTPTest do
  @doc false

  use Mithril.Web.ConnCase

  alias Mithril.OTP
  alias Mithril.OTP.Schema, as: OTPSchema

  describe "create otp" do
    test "success" do
      System.put_env("OTP_LENGTH", "4")
      key = "+380301112233"
      assert {:ok, %OTPSchema{key: ^key, code: code}} = OTP.initialize_otp(key)
      assert 4 == code |> Integer.digits |> length
      System.put_env("OTP_LENGTH", "6")
    end
  end

  describe "verify" do
    setup do
      rand = :rand.uniform(8000) + 1000
      {:ok, otp} = OTP.initialize_otp("38030111#{rand}")
      %{otp: otp}
    end

    test "success", %{otp: otp} do
      assert {:ok, %OTPSchema{status: "VERIFIED"}, :verified} = OTP.verify(otp.key, otp.code)
    end

    test "invalid key" do
      assert_raise Ecto.NoResultsError, fn -> OTP.verify("invalid", 123) end
    end

    test "invalid code", %{otp: otp} do
      assert {:ok, %OTPSchema{status: "NEW"}, :invalid_code} = OTP.verify(otp.key, 300)
    end

    test "reached max attempts", %{otp: otp} do
      for _ <- 1..3, do: OTP.verify(otp.key, 300)

      assert {:ok, %OTPSchema{status: "UNVERIFIED"}, :reached_max_attempts} = OTP.verify(otp.key, otp.code)
    end

    test "on last attempt", %{otp: otp} do
      for _ <- 1..2, do: OTP.verify(otp.key, 300)

      assert {:ok, %OTPSchema{status: "VERIFIED"}, :verified} = OTP.verify(otp.key, otp.code)
    end

    test "OTP expired", %{otp: otp} do
      :timer.sleep(1000)
      assert {:ok, %OTPSchema{status: "EXPIRED"}, :expired} = OTP.verify(otp.key, otp.code)
    end

    test "alredy verified", %{otp: otp} do
      OTP.verify(otp.key, otp.code)
      assert_raise Ecto.NoResultsError, fn -> OTP.verify(otp.key, otp.code) end
    end
  end

  test "cancel_expired_otps" do
    expired_time = 1464096368 |> DateTime.from_unix!() |> DateTime.to_string()
    insert(:otp, status: "CANCELED", active: false, code_expired_at: expired_time)
    %{id: expired_id1} = insert(:otp, code_expired_at: expired_time)
    %{id: expired_id2} = insert(:otp, code_expired_at: expired_time)

    key = "otp-key"
    {:ok, otp} = OTP.initialize_otp(key)
    {:ok, otp, :verified} = OTP.verify(key, otp.code)

    OTP.update_otp(otp, %{code_expired_at: expired_time})

    OTP.cancel_expired_otps()
    otps =
      OTPSchema
      |> where([status: "EXPIRED"])
      |> Repo.all()

    Enum.each(otps, fn %{id: id} ->
      assert id in [expired_id1, expired_id2]
    end)
  end
end

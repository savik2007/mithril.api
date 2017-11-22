defmodule Mithril.OTPTest do
  @doc false

  use Mithril.Web.ConnCase

  alias Mithril.OTP
  alias Mithril.OTP.Schema, as: OTPSchema

  describe "create otp" do
    test "success" do
      key = "+380301112233"
      assert {:ok, %OTPSchema{key: ^key}} = OTP.initialize_otp(key)
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
end

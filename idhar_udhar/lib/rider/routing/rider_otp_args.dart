/// Distinguishes existing-rider login OTP from new-rider registration OTP.
enum RiderAuthFlow { login, registration }

class RiderOtpArgs {
  const RiderOtpArgs({
    this.mobile,
    this.flow = RiderAuthFlow.login,
  });

  final String? mobile;
  final RiderAuthFlow flow;
}

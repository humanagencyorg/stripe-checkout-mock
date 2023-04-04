require_relative "../spec_helper"
require "stripe_checkout_mock/sleep_util"

RSpec.describe StripeCheckoutMock::SleepUtil do
  it "should sleep" do
    time_start = Time.now

    described_class.short_random_sleep

    time_end = Time.now
    expect(time_end - time_start).to be > 0
  end

  it "sleep should be very short" do
    time_start = Time.now

    described_class.short_random_sleep

    time_end = Time.now
    expect(time_end - time_start).to be <= 0.1
  end
end

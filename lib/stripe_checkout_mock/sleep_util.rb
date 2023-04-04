module StripeCheckoutMock
  module SleepUtil
    def self.short_random_sleep
      sleep(rand(0.01..0.099))
    end
  end
end

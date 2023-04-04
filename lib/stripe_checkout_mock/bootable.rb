require "socket"
require "capybara"
require "capybara/server"
require "stripe_checkout_mock/sleep_util"

module StripeCheckoutMock
  module Bootable
    def boot_once
      @boot_once ||= boot
    end

    def port
      @port ||= find_available_port
    end

    private

    def boot
      instance = new

      Capybara::Server.
        new(instance, port: port).
        tap(&:boot)
    end

    def find_available_port
     ::StripeCheckoutMock::SleepUtil.short_random_sleep
      server = TCPServer.new(0)
      server.addr[1]
    ensure
      server&.close
    end
  end
end

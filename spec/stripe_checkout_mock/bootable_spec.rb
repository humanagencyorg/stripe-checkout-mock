require_relative "../spec_helper"

require "socket"
require "stripe_checkout_mock/bootable"
require "stripe_checkout_mock/sleep_util"

RSpec.describe StripeCheckoutMock::Bootable do
  describe ".port" do
    it "returns available port" do
      dummy_class = Class.new { extend StripeCheckoutMock::Bootable }
      fake_server_addr = ["AF_INET6", 9292, "::", "::"]
      server_instance = instance_double(TCPServer)

      allow(TCPServer).
        to receive(:new).
        and_return(server_instance)
      allow(server_instance).
        to receive(:addr).
        and_return(fake_server_addr)
      allow(server_instance).to receive(:close)

      expect(dummy_class.port).to eq(9292)
      expect(TCPServer).to have_received(:new).with(0)
    end

    it "memoizes port" do
      dummy_class = Class.new { extend StripeCheckoutMock::Bootable }
      fake_server_addr = ["AF_INET6", 3000, "::", "::"]
      server_instance = instance_double(TCPServer)

      allow(TCPServer).
        to receive(:new).
        and_return(server_instance)
      allow(server_instance).
        to receive(:addr).
        and_return(fake_server_addr)
      allow(server_instance).to receive(:close)

      results = Array.new(3) { dummy_class.port }

      expect(results.uniq).to eq([3000])
      expect(TCPServer).to have_received(:new).with(0).once
    end

    it "avoids port contention" do
      dummy_class = Class.new { extend StripeCheckoutMock::Bootable }
      fake_server_addr = ["AF_INET6", 3000, "::", "::"]
      server_instance = instance_double(TCPServer)
      sleep_stub = class_double(StripeCheckoutMock::SleepUtil).as_stubbed_const

      allow(sleep_stub).
        to receive(:short_random_sleep)
      allow(TCPServer).
        to receive(:new).
        and_return(server_instance)
      allow(server_instance).
        to receive(:addr).
        and_return(fake_server_addr)
      allow(server_instance).to receive(:close)

      Array.new(3) { dummy_class.port }

      expect(sleep_stub).to have_received(:short_random_sleep).once
    end
  end

  describe ".boot_once" do
    it "starts capybara server with defined port" do
      dummy_class = Class.new { extend StripeCheckoutMock::Bootable }
      dummy_class_instance = instance_double(dummy_class)
      server_instance = instance_double(Capybara::Server)

      allow(dummy_class).to receive(:port).and_return(9292)
      allow(dummy_class).to receive(:new).and_return(dummy_class_instance)
      allow(Capybara::Server).to receive(:new).and_return(server_instance)
      allow(server_instance).to receive(:boot)

      result = dummy_class.boot_once

      expect(result).to eq(server_instance)
      expect(Capybara::Server).
        to have_received(:new).
        with(dummy_class_instance, port: 9292)
      expect(server_instance).to have_received(:boot)
    end

    it "memoizes server" do
      dummy_class = Class.new do
        extend StripeCheckoutMock::Bootable
      end
      dummy_class_instance = instance_double(dummy_class)
      server_instance = instance_double(Capybara::Server)

      allow(dummy_class).to receive(:port).and_return(9292)
      allow(dummy_class).to receive(:new).and_return(dummy_class_instance)
      allow(Capybara::Server).to receive(:new).and_return(server_instance)
      allow(server_instance).to receive(:boot)

      results = Array.new(3) { dummy_class.boot_once }

      expect(results.uniq).to eq([server_instance])
      expect(Capybara::Server).
        to have_received(:new).
        with(dummy_class_instance, port: 9292).
        once
    end
  end
end

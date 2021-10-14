# frozen_string_literal: true

require "uri"
require_relative "stripe_checkout_mock/version"
require_relative "stripe_checkout_mock/server"
require_relative "stripe_checkout_mock/queues/webhook_queue"

module StripeCheckoutMock
  NOT_DEFINED_ERROR =
    "StripeCheckoutMock designed to work with StripeMock together."
  TURNED_OFF_ERROR =
    "StripeMock should be started before StripeCheckoutMock."

  @webhook_url = nil
  @webhook_secret = nil
  @webhook_queue = nil
  @checkout_url = nil
  @manage_url = nil

  class << self
    attr_accessor :webhook_url, :webhook_secret
    attr_reader :webhook_queue, :checkout_url, :manage_url

    def start
      raise NOT_DEFINED_ERROR unless const_defined?(:StripeMock)
      raise TURNED_OFF_ERROR unless StripeMock.instance

      @webhook_queue = StripeCheckoutMock::Queues::WebhookQueue.new
      StripeCheckoutMock::Server.boot_once.tap do |server|
        @checkout_url = "#{server.base_url}/stripe/checkout/"
        @manage_url = "#{server.base_url}/manage"
      end
    end

    def manage_portal(args)
      url = URI(@manage_url)
      url.query = "return_url=#{args[:return_url]}"\
                  "&customer=#{args[:customer]}"
      OpenStruct.new(url: url.to_s)
    end

    def stop
      @webhook_url = nil
      @webhook_secret = nil
      @webhook_queue = nil
      @checkout_url = nil
      @manage_url = nil
    end
  end
end

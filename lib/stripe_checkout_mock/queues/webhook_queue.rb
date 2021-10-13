require "uri"
require "net/http"
require "stripe"

require_relative "./base_queue"

module StripeCheckoutMock
  module Queues
    class WebhookQueue
      include BaseQueue

      def deliver_latest
        event = pop
        raise "Queue is empty" unless event

        Net::HTTP.post(
          URI(StripeCheckoutMock.webhook_url),
          event.to_json,
          {
            "Content-Type" => "application/json",
            "Stripe-Signature" => prepare_signature(event),
          },
        )
      end

      private

      def prepare_signature(event)
        time = Time.now
        secret = StripeCheckoutMock.webhook_secret
        signature = Stripe::Webhook::Signature.
          compute_signature(time, event.to_json, secret)

        Stripe::Webhook::Signature.generate_header(
          time,
          signature,
          scheme: Stripe::Webhook::Signature::EXPECTED_SCHEME,
        )
      end
    end
  end
end

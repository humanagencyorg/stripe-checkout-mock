require_relative "../../spec_helper"
require "stripe_mock"
require "stripe_checkout_mock/queues/webhook_queue"

RSpec.describe StripeCheckoutMock::Queues::WebhookQueue do
  include_examples "queable"

  describe "#deliver_latest" do
    it "makes http request" do
      webhook_url = "http://hello.com/hook"
      webhook_secret = "fake_secret"
      event = { fiz: :buzz }
      time = Time.now
      signature = Stripe::Webhook::Signature.
        compute_signature(time, event.to_json, webhook_secret)

      header = Stripe::Webhook::Signature.generate_header(
        time,
        signature,
        scheme: Stripe::Webhook::Signature::EXPECTED_SCHEME,
      )
      allow(Time).to receive(:now).and_return(time)
      StripeCheckoutMock.webhook_url = webhook_url
      StripeCheckoutMock.webhook_secret = webhook_secret

      request = stub_request(:post, webhook_url).
        with(
          body: event.to_json,
          headers: {
            "Accept" => "*/*",
            "Accept-Encoding" => "gzip;q=1.0,deflate;q=0.6,identity;q=0.3",
            "Content-Type" => "application/json",
            "Host" => "hello.com",
            "Stripe-Signature" => header,
            "User-Agent" => "Ruby",

          },
        ).
        to_return(status: 200, body: "", headers: {})

      instance = described_class.new
      instance.add(event)
      instance.deliver_latest

      expect(request).to have_been_requested
    end

    it "removes lates element from queue" do
      webhook_url = "http://hello.com/hook"
      webhook_secret = "fake_secret"
      event = { fiz: :buzz }
      time = Time.now
      signature = Stripe::Webhook::Signature.
        compute_signature(time, event.to_json, webhook_secret)

      header = Stripe::Webhook::Signature.generate_header(
        time,
        signature,
        scheme: Stripe::Webhook::Signature::EXPECTED_SCHEME,
      )
      allow(Time).to receive(:now).and_return(time)
      StripeCheckoutMock.webhook_url = webhook_url
      StripeCheckoutMock.webhook_secret = webhook_secret
      stub_request(:post, webhook_url).
        with(
          body: event.to_json,
          headers: {
            "Accept" => "*/*",
            "Accept-Encoding" => "gzip;q=1.0,deflate;q=0.6,identity;q=0.3",
            "Content-Type" => "application/json",
            "Host" => "hello.com",
            "Stripe-Signature" => header,
            "User-Agent" => "Ruby",

          },
        ).
        to_return(status: 200, body: "", headers: {})

      instance = described_class.new
      instance.add(event)

      expect { instance.deliver_latest }.
        to change { instance.instance_variable_get(:@queue) }.
        from([event]).
        to([])
    end

    context "when empty" do
      it "raises exception" do
        instance = described_class.new

        expect { instance.deliver_latest }.
          to raise_error("Queue is empty")
      end
    end
  end
end

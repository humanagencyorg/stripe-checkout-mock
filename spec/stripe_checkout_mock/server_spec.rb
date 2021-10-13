require_relative "../spec_helper"

require "socket"
require "stripe_mock"
require "nokogiri"
require "stripe_checkout_mock/server"
require "stripe_checkout_mock/queues/webhook_queue"

RSpec.describe StripeCheckoutMock::Server do
  module RSpecMixin # rubocop:disable Lint/ConstantDefinitionInBlock
    include Rack::Test::Methods

    def app
      described_class
    end
  end

  before do
    StripeMock.start

    RSpec.configure do |c|
      c.include RSpecMixin
    end
  end

  after do
    StripeMock.stop
  end

  describe "requests" do
    describe "GET /stripe/checkout/:session_id" do
      it "renders checkout and cancel buttons" do
        success_url = "https://fake_success.com"
        cancel_url = "https://fake_cancel.com"
        session = Stripe::Checkout::Session.create(
          customer: "fake_customer_id",
          success_url: success_url,
          cancel_url: cancel_url,
          payment_method_types: ["card"],
          mode: "subscription",
          line_items: [
            {
              price: "fake_price_id",
              quantity: 1,
            },
          ],
        )
        expected_checkout_path =
          "/stripe/checkout/#{session.id}/subscribe"

        get "/stripe/checkout/#{session.id}"

        doc = Nokogiri::HTML(last_response.body)
        form = doc.search("form#checkout").first
        expect(form).not_to be_nil
        expect(form["action"]).to eq(expected_checkout_path)
        expect(form["method"]).to eq("post")
        submit = doc.search("form#checkout input[type='submit']").first
        expect(submit).not_to be_nil

        cancel = doc.search("a#cancel").first
        expect(cancel).not_to be_nil
        expect(cancel["href"]).to eq(cancel_url)
      end
    end

    describe "POST /stripe/checkout/:session_id/subscribe" do
      it "redirects user to success_url" do
        success_url = "https://fake_success.com"
        cancel_url = "https://fake_cancel.com"
        queue = instance_double(
          StripeCheckoutMock::Queues::WebhookQueue,
          add: nil,
        )
        StripeCheckoutMock.instance_variable_set(:@webhook_queue, queue)
        session = Stripe::Checkout::Session.create(
          customer: "fake_customer_id",
          success_url: success_url,
          cancel_url: cancel_url,
          payment_method_types: ["card"],
          mode: "subscription",
          line_items: [
            {
              price: "fake_price_id",
              quantity: 1,
            },
          ],
        )

        post "/stripe/checkout/#{session.id}/subscribe"

        expect(last_response.status).to eq(302)
        expect(last_response.headers["Location"]).to eq(success_url)
      end

      it "enqueues checkout success event" do
        success_url = "https://fake_success.com"
        cancel_url = "https://fake_cancel.com"
        session = Stripe::Checkout::Session.create(
          customer: "fake_customer_id",
          success_url: success_url,
          cancel_url: cancel_url,
          payment_method_types: ["card"],
          mode: "subscription",
          line_items: [
            {
              price: "fake_price_id",
              quantity: 1,
            },
          ],
        )
        event = { fake: :event }
        queue = instance_double(StripeCheckoutMock::Queues::WebhookQueue)
        allow(StripeMock).to receive(:mock_webhook_event).
          and_return(event)
        allow(StripeCheckoutMock).to receive(:webhook_queue).
          and_return(queue)
        allow(queue).to receive(:add)

        post "/stripe/checkout/#{session.id}/subscribe"

        expect(last_response.status).to eq(302)
        expect(StripeMock).to have_received(:mock_webhook_event).
          with("checkout.session.completed", id: session.id)
        expect(StripeCheckoutMock).to have_received(:webhook_queue)
        expect(queue).to have_received(:add).
          with(event)
      end
    end
  end
end

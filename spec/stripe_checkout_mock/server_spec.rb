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
        submit = form.search("input[type='submit']").first
        expect(submit).not_to be_nil

        cancel = doc.search("a#cancel").first
        expect(cancel).not_to be_nil
        expect(cancel["href"]).to eq(cancel_url)
      end
    end

    describe "GET /manage" do
      it "renders pay and cancel buttons" do
        customer = "fake_customer"
        return_url = "https://fake_return.com?fizz=buzz&hello=world"
        expected_checkout_path = "/manage/pay"

        get "/manage", return_url: return_url, customer: customer

        doc = Nokogiri::HTML(last_response.body)

        return_button = doc.search("a#return").first
        expect(return_button).not_to be_nil
        expect(return_button["href"]).to eq(return_url)

        doc = Nokogiri::HTML(last_response.body)
        form = doc.search("form#pay").first
        expect(form).not_to be_nil
        expect(form["action"]).to eq(expected_checkout_path)
        expect(form["method"]).to eq("post")

        hidden1 = form.search("input[name='customer']").first
        expect(hidden1).not_to be_nil
        expect(hidden1[:value]).to eq(customer)

        hidden2 = form.search("input[name='return_url']").first
        expect(hidden2).not_to be_nil
        expect(hidden2[:value]).to eq(return_url)

        submit = form.search("input[type='submit']").first
        expect(submit).not_to be_nil
      end
    end

    describe "POST /stripe/checkout/:session_id/subscribe" do
      it "redirects user to success_url" do
        success_url = "https://fake_success.com"
        cancel_url = "https://fake_cancel.com"
        customer =
          Stripe::Customer.create(source: StripeMock.generate_card_token)
        product = Stripe::Product.create(name: "Product")
        price = Stripe::Price.create(product: product.id, currency: "usd")

        queue = instance_double(
          StripeCheckoutMock::Queues::WebhookQueue,
          add: nil,
        )
        StripeCheckoutMock.instance_variable_set(:@webhook_queue, queue)
        session = Stripe::Checkout::Session.create(
          customer: customer.id,
          success_url: success_url,
          cancel_url: cancel_url,
          payment_method_types: ["card"],
          mode: "subscription",
          line_items: [
            {
              price: price.id,
              quantity: 1,
            },
          ],
        )

        post "/stripe/checkout/#{session.id}/subscribe"

        expect(last_response.status).to eq(302)
        expect(last_response.headers["Location"]).to eq(success_url)
      end

      it "creates subscription" do
        success_url = "https://fake_success.com"
        cancel_url = "https://fake_cancel.com"
        customer =
          Stripe::Customer.create(source: StripeMock.generate_card_token)
        product = Stripe::Product.create(name: "Product")
        price = Stripe::Price.create(product: product.id, currency: "usd")

        queue = instance_double(
          StripeCheckoutMock::Queues::WebhookQueue,
          add: nil,
        )
        StripeCheckoutMock.instance_variable_set(:@webhook_queue, queue)
        session = Stripe::Checkout::Session.create(
          customer: customer.id,
          success_url: success_url,
          cancel_url: cancel_url,
          payment_method_types: ["card"],
          mode: "subscription",
          line_items: [
            {
              price: price.id,
              quantity: 1,
            },
          ],
        )

        post "/stripe/checkout/#{session.id}/subscribe"

        reloaded_sesssion = Stripe::Checkout::Session.retrieve(session.id)
        expect(reloaded_sesssion.subscription).to be_present

        subscription =
          Stripe::Subscription.retrieve(reloaded_sesssion.subscription)
        expect(subscription).to be_present
        expect(subscription.items.count).to eq(1)
      end

      it "enqueues checkout success event" do
        success_url = "https://fake_success.com"
        cancel_url = "https://fake_cancel.com"
        customer =
          Stripe::Customer.create(source: StripeMock.generate_card_token)
        product = Stripe::Product.create(name: "Product")
        price = Stripe::Price.create(product: product.id, currency: "usd")
        session = Stripe::Checkout::Session.create(
          customer: customer.id,
          success_url: success_url,
          cancel_url: cancel_url,
          payment_method_types: ["card"],
          mode: "subscription",
          line_items: [
            {
              price: price.id,
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

        reloaded_sesssion = Stripe::Checkout::Session.retrieve(session.id)
        expect(last_response.status).to eq(302)
        expect(StripeMock).to have_received(:mock_webhook_event).
          with(
            "checkout.session.completed",
            id: session.id,
            subscription: reloaded_sesssion.subscription,
          )
        expect(StripeCheckoutMock).to have_received(:webhook_queue)
        expect(queue).to have_received(:add).
          with(event)
      end
    end

    describe "POST /manage/pay" do
      it "updates subscription and redirect user" do
        return_url = "https://fake_return.com"
        customer =
          Stripe::Customer.create(source: StripeMock.generate_card_token)
        product = Stripe::Product.create(name: "Product")
        price = Stripe::Price.create(product: product.id, currency: "usd")
        subscription = Stripe::Subscription.create(
          customer: customer,
          items: [{ price: price.id }],
        )
        StripeMock.instance.subscriptions[subscription.id][:status] = "unpaid"

        event = { fake: :event }
        queue = instance_double(StripeCheckoutMock::Queues::WebhookQueue)
        allow(StripeMock).to receive(:mock_webhook_event).
          and_return(event)
        allow(StripeCheckoutMock).to receive(:webhook_queue).
          and_return(queue)
        allow(queue).to receive(:add)

        post "/manage/pay", { customer: customer.id, return_url: return_url }

        expect(last_response.status).to eq(302)
        expect(last_response.headers["Location"]).to eq(return_url)

        reloaded_subscription = Stripe::Subscription.retrieve(subscription.id)
        expect(reloaded_subscription.status).to eq("active")
      end

      it "enqueues subscription update event" do
        return_url = "https://fake_return.com"
        customer =
          Stripe::Customer.create(source: StripeMock.generate_card_token)
        product = Stripe::Product.create(name: "Product")
        price = Stripe::Price.create(product: product.id, currency: "usd")
        subscription = Stripe::Subscription.create(
          customer: customer,
          items: [{ price: price.id }],
        )
        StripeMock.instance.subscriptions[subscription.id][:status] = "unpaid"

        event = { fake: :event }
        queue = instance_double(StripeCheckoutMock::Queues::WebhookQueue)
        allow(StripeMock).to receive(:mock_webhook_event).
          and_return(event)
        allow(StripeCheckoutMock).to receive(:webhook_queue).
          and_return(queue)
        allow(queue).to receive(:add)

        post "/manage/pay", { customer: customer.id, return_url: return_url }

        expect(last_response.status).to eq(302)
        expect(StripeMock).to have_received(:mock_webhook_event).
          with(
            "customer.subscription.updated",
            id: subscription.id,
            customer: customer.id,
          )
        expect(StripeCheckoutMock).to have_received(:webhook_queue)
        expect(queue).to have_received(:add).with(event)
      end
    end
  end
end

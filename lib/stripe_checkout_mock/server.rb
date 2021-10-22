# frozen_string_literal: true

require "sinatra/base"

require "stripe_checkout_mock/bootable"

module StripeCheckoutMock
  class Server < Sinatra::Base
    extend Bootable

    get "/stripe/checkout/:session_id" do
      session = Stripe::Checkout::Session.retrieve(params["session_id"])
      checkout_form = <<~HTML
        <form id="checkout"
              action="/stripe/checkout/#{params['session_id']}/subscribe"
              method="post">
          <input type="submit">
        </form>
      HTML

      cancel_button = "<a href='#{session.cancel_url}' id='cancel'>Cancel</a>"

      with_template do
        checkout_form + cancel_button
      end
    end

    post "/stripe/checkout/:session_id/subscribe" do
      session = Stripe::Checkout::Session.retrieve(params["session_id"])
      payment_method = Stripe::PaymentMethod.create(type: "card")
      subscription = StripeMock.create_test_helper.
        complete_checkout_session(session, payment_method)
      StripeMock.instance.
        checkout_sessions[params["session_id"]][:subscription] = subscription.id
      event = StripeMock.mock_webhook_event(
        "checkout.session.completed",
        id: session.id,
        subscription: subscription.id,
      )
      StripeCheckoutMock.webhook_queue.add(event)

      redirect session.success_url
    end

    get "/manage" do
      pay_form = <<~HTML
        <form id="pay" action="/manage/pay" method="post">
          <input type="hidden" name="customer" value="#{params[:customer]}">
          <input type="hidden" name="return_url" value="#{params[:return_url]}">

          <input type="submit">
        </form>
      HTML

      return_button = "<a href='#{params[:return_url]}' id='return'>Cancel</a>"

      with_template do
        pay_form + return_button
      end
    end

    post "/manage/pay" do
      subscription = Stripe::Customer.
        retrieve(params["customer"]).
        subscriptions.
        first

      StripeMock.instance.subscriptions[subscription.id][:status] = "active"
      event = StripeMock.mock_webhook_event(
        "customer.subscription.updated",
        id: subscription.id,
        customer: params["customer"],
      )
      StripeCheckoutMock.webhook_queue.add(event)

      redirect params["return_url"]
    end

    private

    def with_template
      <<-HTML
        <html>
          <head>
            <title>Stripe Checkout Mock</title>
            <meta charset="utf-8" />
          </head>
          <body>#{yield}</body>
        </html>
      HTML
    end
  end
end

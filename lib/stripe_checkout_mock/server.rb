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
      event = StripeMock.mock_webhook_event(
        "checkout.session.completed",
        id: session.id,
      )
      StripeCheckoutMock.webhook_queue.add(event)

      redirect session.success_url
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

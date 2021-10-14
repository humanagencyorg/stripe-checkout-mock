require_relative "./spec_helper"
require "cgi"
require "stripe_mock"
require "stripe_checkout_mock/server"
require "stripe_checkout_mock/queues/webhook_queue"

RSpec.describe StripeCheckoutMock do
  describe ".start" do
    it "starts server" do
      StripeMock.start
      host = "http://localhost:5353"
      server = instance_double(Capybara::Server, base_url: host)
      allow(StripeCheckoutMock::Server).
        to receive(:boot_once).and_return(server)

      described_class.start

      expect(StripeCheckoutMock::Server).to have_received(:boot_once)

      StripeMock.stop
      clean_instance_variables
    end

    it "creates fresh webhook queue" do
      StripeMock.start

      queue = instance_double(described_class::Queues::WebhookQueue)
      host = "http://localhost:5353"
      server = instance_double(Capybara::Server, base_url: host)
      allow(StripeCheckoutMock::Server).
        to receive(:boot_once).and_return(server)
      allow(described_class::Queues::WebhookQueue).to receive(:new).
        and_return(queue)

      described_class.start

      expect(described_class.webhook_queue).to eq(queue)

      StripeMock.stop
      clean_instance_variables
    end

    it "sets checkout_url" do
      StripeMock.start
      host = "http://localhost:5353"
      server = instance_double(Capybara::Server, base_url: host)
      expected_url = "#{host}/stripe/checkout/"
      allow(StripeCheckoutMock::Server).
        to receive(:boot_once).and_return(server)

      expect { described_class.start }.
        to change(described_class, :checkout_url).
        from(nil).
        to(expected_url)

      StripeMock.stop
      clean_instance_variables
    end

    it "sets manage_url" do
      StripeMock.start
      host = "http://localhost:5353"
      server = instance_double(Capybara::Server, base_url: host)
      expected_url = "#{host}/manage"
      allow(StripeCheckoutMock::Server).
        to receive(:boot_once).and_return(server)

      expect { described_class.start }.
        to change(described_class, :manage_url).
        from(nil).
        to(expected_url)

      StripeMock.stop
      clean_instance_variables
    end

    context "when StripeMock not loaded" do
      it "raises an error" do
        allow(StripeCheckoutMock).to receive(:const_defined?).and_return(false)
        expected_error =
          "StripeCheckoutMock designed to work with StripeMock together."

        expect { described_class.start }.
          to raise_error(expected_error)

        clean_instance_variables
      end
    end

    context "when StripeMock is not started" do
      it "raise an error" do
        expected_error =
          "StripeMock should be started before StripeCheckoutMock."

        expect { described_class.start }.
          to raise_error(expected_error)

        clean_instance_variables
      end
    end
  end

  describe ".stop" do
    it "resets all instance variables" do
      variables = %i[@webhook_url @webhook_queue @webhook_secret @checkout_url
                     @manage_url]
      variables.each do |name|
        described_class.instance_variable_set(name, "fake_data")
      end

      described_class.stop

      variables.each do |name|
        expect(described_class.instance_variable_get(name)).to eq(nil)
      end
    end
  end

  describe ".manage_portal" do
    it "returns OpenStruct object with url" do
      StripeMock.start

      host = "http://localhost:5353"
      return_url = "https://fake.url?fizz=buzz&hello=world"
      escaped_url = CGI.escape(return_url)
      customer = "cus_fake_id"

      server = instance_double(Capybara::Server, base_url: host)
      allow(StripeCheckoutMock::Server).
        to receive(:boot_once).and_return(server)
      described_class.start

      result = described_class.manage_portal(
        return_url: return_url,
        customer: customer,
      )

      expected_url =
        "#{host}/manage?return_url=#{escaped_url}&customer=#{customer}"
      expect(result).to be_a(OpenStruct)
      expect(result.url).to eq(expected_url)
      StripeMock.stop
    end
  end

  describe "webhook_url attr_accessor" do
    it "returns webhook_url" do
      url1 = "fake url"
      url2 = "fake url 2"

      expect(described_class.webhook_url).to be_nil

      described_class.webhook_url = url1

      expect(described_class.webhook_url).to eq(url1)

      described_class.webhook_url = url2

      expect(described_class.webhook_url).to eq(url2)

      clean_instance_variables
    end
  end

  describe "webhook_secret attr_accessor" do
    it "returns webhook_url" do
      secret1 = "secret"
      secret2 = "secret 2"

      expect(described_class.webhook_secret).to be_nil

      described_class.webhook_secret = secret1

      expect(described_class.webhook_secret).to eq(secret1)

      described_class.webhook_secret = secret2

      expect(described_class.webhook_secret).to eq(secret2)

      clean_instance_variables
    end
  end

  describe "webhook_queue attr_readed" do
    it "returns webhook_url" do
      queue = instance_double(described_class::Queues::WebhookQueue)
      described_class.instance_variable_set(:@webhook_queue, queue)

      expect(described_class.webhook_queue).to eq(queue)

      clean_instance_variables
    end
  end

  def clean_instance_variables
    %i[@webhook_url @webhook_queue @webhook_secret @checkout_url
       @manage_url].each do |name|
      described_class.instance_variable_set(name, nil)
    end
  end
end

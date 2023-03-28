# frozen_string_literal: true

require_relative "lib/stripe_checkout_mock/version"

Gem::Specification.new do |spec| # rubocop:disable Metrics/BlockLength
  spec.name          = "stripe-checkout-mock"
  spec.version       = StripeCheckoutMock::VERSION
  spec.authors       = ["Alex Beznos"]
  spec.email         = ["alex.b@humanagency.com"]

  spec.summary       = "StripeMock for checkout page"
  spec.description   = "This gem works together with stripe-ruby-mock to make "\
                       "a similar behavior to checkout process"
  spec.homepage      = "https://github.com/humanagency/stripe-checkout-mock"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 2.7.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/humanagency/stripe-checkout-mock"
  spec.metadata["changelog_uri"] = "https://github.com/humanagency/stripe-checkout-mock"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject do |f|
      f.match(%r{\A(?:test|spec|features)/})
    end
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "nokogiri"
  spec.add_development_dependency "pry", "~> 0.13"
  spec.add_development_dependency "rake", ">= 12.3.3"
  spec.add_development_dependency "rubocop", ">= 0.82"
  spec.add_development_dependency "rubocop-rake"
  spec.add_development_dependency "rubocop-rspec"
  spec.add_development_dependency "webmock"

  spec.add_runtime_dependency "activesupport"
  spec.add_runtime_dependency "capybara"
  spec.add_runtime_dependency "sinatra", ">= 2.2.2"
  spec.add_runtime_dependency "stripe"
end

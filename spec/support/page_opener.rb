module PageOpener
  def open_page
    file = Tempfile.new(["last_page", ".html"])

    file.write(last_response.body)

    `open #{file.path}`
  end
end

RSpec.configure do |config|
  config.include PageOpener
end

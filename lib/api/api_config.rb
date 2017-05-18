require "config"

module Api
  ApiConfig = ::Config::Options.new.tap do |o|
    o.add_source!(Rails.root.join("config/api.yml").to_s)
    o.load!
  end
end

if ENV['CI']
  require 'simplecov'
  SimpleCov.start
end
<% if options[:vcr] %>
VCR.configure do |config|
  config.ignore_hosts 'codeclimate.com' if ENV['CI']
  config.cassette_library_dir = File.join(ManageIQ::Providers::<%= class_name %>::Engine.root, 'spec/vcr_cassettes')
end
<% else %>
# Uncomment in case you use vcr cassettes
# VCR.configure do |config|
#   config.ignore_hosts 'codeclimate.com' if ENV['CI']
#   config.cassette_library_dir = File.join(ManageIQ::Providers::<%= class_name %>::Engine.root, 'spec/vcr_cassettes')
# end
<% end %>
Dir[Rails.root.join("spec/shared/**/*.rb")].each { |f| require f }
Dir[ManageIQ::Providers::<%= class_name %>::Engine.root.join("spec/support/**/*.rb")].each { |f| require f }

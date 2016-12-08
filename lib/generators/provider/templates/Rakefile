begin
  require 'bundler/setup'
rescue LoadError
  puts 'You must `gem install bundler` and `bundle install` to run rake tasks'
end

APP_RAKEFILE = File.expand_path("../spec/manageiq/Rakefile", __FILE__)
load 'rails/tasks/engine.rake'

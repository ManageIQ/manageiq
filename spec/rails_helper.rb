require 'spec_helper'

# TODO:
# * require *this* file instead of spec_helper in the specs.
# * Move any Rails specific code and setup from spec_helper.rb to this file.

Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end


require 'yaml'

require_relative 'kernel_require_patch'

ENV['LOG_LEVEL']              = "FATAL"
ENV["RAILS_ENV"]              = "production"
ENV['RACK_ENV']               = ENV["RAILS_ENV"]
ENV["DISABLE_SPRING"]         = "true"
ENV['RAILS_USE_MEMORY_STORE'] = "1"

require ::File.expand_path('../../../config/application', __FILE__)

Vmdb::Application.configure do
  config.instance_variable_set(:@eager_load, true)
end

# Prevent overriding the @eager_load variable in the `config/environments/production.rb`
class Rails::Application::Configuration
  def eager_load=(value)
  end

  def eager_load_paths=(value)
  end
end

Vmdb::Application.initialize!

TOP_REQUIRE.set_top_require_cost

# puts TOP_REQUIRE.flattened_full_hash_output.to_yaml
TOP_REQUIRE.print_sorted_children
TOP_REQUIRE.print_summary

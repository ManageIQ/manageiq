module RSpec::Fire
  # rspec-fire does not detect ActiveRecord methods that get defined
  # implicitly from the database, so we force AR to load the fields
  # by creating an instance of the AR object
  def active_record_instance_double(double_name, stubs = {})
    double_name.constantize.new
    instance_double(double_name, stubs)
  end
end

RSpec::Fire.configure do |config|
  config.verify_constant_names = true
end

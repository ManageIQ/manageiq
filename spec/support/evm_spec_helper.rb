# Set env var LOG_TO_CONSOLE if you want logging to dump to the console
# e.g. LOG_TO_CONSOLE=true ruby spec/models/vm.rb
$log.logdev = STDERR if ENV['LOG_TO_CONSOLE']

# Set env var LOGLEVEL if you want custom log level during a local test
# e.g. LOG_LEVEL=debug ruby spec/models/vm.rb
env_level = VMDBLogger.const_get(ENV['LOG_LEVEL'].to_s.upcase) rescue nil if ENV['LOG_LEVEL']
env_level ||= VMDBLogger::INFO
$log.level = env_level
Rails.logger.level = env_level

module EvmSpecHelper
  # Clear all EVM caches
  def self.clear_caches
    Module.clear_all_cache_with_timeout if Module.respond_to?(:clear_all_cache_with_timeout)

    clear_instance_variables(MiqEnvironment::Command)
    clear_instance_variable(MiqProductFeature, :@feature_cache) if defined?(MiqProductFeature)
    clear_instance_variable(BottleneckEvent, :@event_definitions) if defined?(BottleneckEvent)

    # Clear the thread local variable to prevent test contamination
    User.current_userid = nil if defined?(User) && User.respond_to?(:current_userid=)

    # Clear configuration caches
    VMDB::Config.invalidate_all
  end

  def self.clear_instance_variables(instance)
    if instance.kind_of?(ActiveRecord::Base) || (instance.kind_of?(Class) && instance < ActiveRecord::Base)
      raise "instances variables should not be cleared from ActiveRecord objects"
    end
    # Don't clear the rspec-mocks instance variables
    ivars = instance.instance_variables - [:@mock_proxy, :@__recorder]
    ivars.each { |ivar| clear_instance_variable(instance, ivar) }
  end

  def self.clear_instance_variable(instance, ivar)
    instance.instance_variable_set(ivar, nil)
  end

  def self.create_root_tenant
    Tenant.seed
  end

  def self.local_miq_server(attrs = {})
    remote_miq_server(attrs).tap do |server|
      MiqServer.stub(:my_guid).and_return(server.guid)
      MiqServer.my_server_clear_cache
    end
  end

  def self.local_guid_miq_server_zone
    server = local_miq_server
    [server.guid, server, server.zone]
  end

  class << self
    alias_method :create_guid_miq_server_zone, :local_guid_miq_server_zone
  end

  def self.remote_miq_server(attrs = {})
    create_root_tenant

    server = FactoryGirl.create(:miq_server, attrs)
    server
  end

  def self.remote_guid_miq_server_zone
    server = remote_miq_server
    [server.guid, server, server.zone]
  end

  def self.specific_product_features(*features)
    features.flatten!
    seed_specific_product_features(*features)
    MiqProductFeature.find_all_by_identifier(features)
  end

  def self.seed_specific_product_features(*features)
    features.flatten!
    hashes   = YAML.load_file(MiqProductFeature::FIXTURE_YAML)
    filtered = filter_specific_features([hashes], features).first
    MiqProductFeature.seed_from_hash(filtered)
  end

  def self.filter_specific_features(hashes, features)
    hashes.select do |h|
      h[:children] = filter_specific_features(h[:children], features) if h[:children].present?
      h[:identifier].in?(features) || h[:children].present?
    end
  end
  private_class_method :filter_specific_features

  def self.seed_admin_user_and_friends
    create_guid_miq_server_zone

    FactoryGirl.create(:user,
                       :name       => "Administrator",
                       :email      => "admin@example.com",
                       :password   => "smartvm",
                       :userid     => "admin",
                       :settings   => {"Setting1" => 1, "Setting2" => 2, "Setting3" => 3},
                       :filters    => {"Filter1" => 1, "Filter2" => 2, "Filter3" => 3},
                       :first_name => "Bob",
                       :last_name  => "Smith",
                       :role       => "super_administrator",
                      )
  end

  def self.ruby_object_usage
    types = Hash.new { |h, k| h[k] = Hash.new(0) }
    ObjectSpace.each_object do |obj|
      types[obj.class][:count] += 1
    end
    types
  end

  def self.log_ruby_object_usage(top = 20)
    if top > 0
      types = ruby_object_usage
      puts("Ruby Object Usage: #{types.sort_by { |_klass, h| h[:count] }.reverse[0, top].inspect}")
    end
  end

  def self.stub_amqp_support
    require 'openstack/amqp/openstack_rabbit_event_monitor'
    OpenstackRabbitEventMonitor.stub(:available?).and_return(true)
    OpenstackRabbitEventMonitor.stub(:test_connection).and_return(true)
  end

  def self.import_yaml_model(dirname, domain, attrs = {})
    options = {'import_dir' => dirname, 'preview' => false, 'domain' => domain}
    yaml_import(domain, options, attrs)
  end

  def self.import_yaml_model_from_file(yaml_file, domain, attrs = {})
    options = {'yaml_file' => yaml_file, 'preview' => false, 'domain' => domain}
    yaml_import(domain, options, attrs)
  end

  def self.yaml_import(domain, options, attrs = {})
    MiqAeImport.new(domain, options).import
    dom = MiqAeNamespace.find_by_fqname(domain)
    dom.update_attributes!(attrs.reverse_merge(:enabled => true)) if dom
  end
end

# If run through cruisecontrol, write the normal $log messages to the cruise
# control build artifacts logger
if ENV['CC_BUILD_ARTIFACTS']
  $log.filename = File.expand_path(File.join(ENV['CC_BUILD_ARTIFACTS'], "evm.log"))
  cc_level = VMDBLogger::INFO
end

# Set env var LOG_TO_CONSOLE if you want logging to dump to the console
# e.g. LOG_TO_CONSOLE=true ruby spec/models/vm.rb
$log.logdev = STDERR if ENV['LOG_TO_CONSOLE']

# Set env var LOGLEVEL if you want custom log level during a local test
# e.g. LOG_LEVEL=debug ruby spec/models/vm.rb
env_level = VMDBLogger.const_get(ENV['LOG_LEVEL'].to_s.upcase) rescue nil if ENV['LOG_LEVEL']

$log.level = env_level || cc_level || VMDBLogger::INFO
Rails.logger.level = $log.level

module EvmSpecHelper

  # Clear all EVM caches
  def self.clear_caches
    Module.clear_all_cache_with_timeout if Module.respond_to?(:clear_all_cache_with_timeout)

    clear_instance_variables(MiqEnvironment::Command)
    clear_instance_variable(MiqProductFeature, :@feature_cache)

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

  def self.local_guid_miq_server_zone
    guid, server, zone = remote_guid_miq_server_zone
    MiqServer.stub(:my_guid).and_return(guid)

    return guid, server, zone
  end

  class << self
    alias_method :create_guid_miq_server_zone, :local_guid_miq_server_zone
  end

  def self.remote_guid_miq_server_zone
    guid   = MiqUUID.new_guid
    zone   = FactoryGirl.create(:zone)
    server = FactoryGirl.create(:miq_server_master, :guid => guid, :zone => zone)

    MiqServer.my_server_clear_cache
    zone.clear_association_cache

    return guid, server, zone
  end

  # FIXXME - rename uses of this method
  def self.seed_for_miq_queue
    MiqRegion.seed
    create_guid_miq_server_zone
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
    guid, server, zone = seed_for_miq_queue

    admin_role = FactoryGirl.create(:miq_user_role,
      #:name       => "EvmRole-administrator",
      :name       => "EvmRole-super_administrator",
      :read_only  => true,
      :settings   => nil
    )

    admin_group = FactoryGirl.create(:miq_group,
      :description   => "EvmGroup-super_administrator",
      :miq_user_role => admin_role
    )

    admin_user = FactoryGirl.create(:user,
      :name           => "Administrator",
      :email          => "admin@example.com",
      :password       => "smartvm",
      :userid         => "admin",
      :settings       => {"Setting1"  => 1, "Setting2"  => 2, "Setting3"  => 3 },
      :filters        => {"Filter1"   => 1, "Filter2"   => 2, "Filter3"   => 3 },
      :miq_groups     => [admin_group],
      :first_name     => "Bob",
      :last_name      => "Smith"
    )

    return guid, server, zone, admin_user, admin_group, admin_role
  end

  def self.ruby_object_usage
    types = Hash.new { |h, k| h[k] = Hash.new(0) }
    ObjectSpace.each_object do |obj|
      types[obj.class][:count] += 1
    end
    types
  end

  def self.log_ruby_object_usage(top=20)
    if top > 0
      types = ruby_object_usage
      puts("Ruby Object Usage: #{types.sort_by { |klass, h| h[:count] }.reverse[0,top].inspect}")
    end
  end

  def self.stub_qpid_natives
    require 'openstack/amqp/openstack_qpid_connection'
    OpenstackQpidConnection.stub(:available?).and_return(true)
    qsession = RSpec::Mocks::Mock.new("qpid session")
    qconnection = RSpec::Mocks::Mock.new("qpid connection", :create_session => qsession)
    OpenstackQpidConnection.any_instance.stub(:create_connection).and_return(qconnection)

    return qsession, qconnection
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

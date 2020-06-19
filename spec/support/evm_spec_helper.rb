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
  extend RSpec::Mocks::ExampleMethods

  module EmsMetadataHelper
    def self.vmware_nested_folders(ems)
      datacenters = FactoryBot.create(:ems_folder, :name => 'Datacenters').tap { |x| x.parent = ems }
      nested = FactoryBot.create(:ems_folder, :name => 'nested').tap { |x| x.parent = datacenters }
      testing = FactoryBot.create(:ems_folder, :name => 'testing').tap { |x| x.parent = nested }
      FactoryBot.create(:datacenter).tap { |x| x.parent = testing }
    end
  end

  def self.assign_embedded_ansible_role(miq_server = nil)
    MiqRegion.seed
    miq_server ||= local_miq_server
    ServerRole.find_by(:name => "embedded_ansible") || FactoryBot.create(:server_role, :name => 'embedded_ansible', :max_concurrent => 0)
    miq_server.assign_role('embedded_ansible').update(:active => true)
  end

  # Clear all EVM caches
  def self.clear_caches
    settings_backup
    yield if block_given?
  ensure
    Module.clear_all_cache_with_timeout if Module.respond_to?(:clear_all_cache_with_timeout)

    clear_instance_variables(MiqEnvironment::Command)
    clear_instance_variable(MiqProductFeature, :@feature_cache) if defined?(MiqProductFeature)
    clear_instance_variable(MiqProductFeature, :@obj_cache) if defined?(MiqProductFeature)
    clear_instance_variable(BottleneckEvent, :@event_definitions) if defined?(BottleneckEvent)
    clear_instance_variable(Tenant, :@root_tenant) if defined?(Tenant)

    MiqWorker.my_guid = nil

    # Clear the thread local variable to prevent test contamination
    User.current_user = nil if defined?(User) && User.respond_to?(:current_user=)

    settings_restore if settings_changed?
  end

  private_class_method def self.settings_backup
    @settings_backup ||= settings_dump
  end

  private_class_method def self.settings_restore
    Vmdb::Settings.reset_settings_constant(settings_load(@settings_backup))
  end

  private_class_method def self.settings_dump
    Marshal.dump(::Settings).tap do |dump|
      # Marshal dump of Settings loses the config_sources, so we need to backup manually
      dump.instance_variable_set(:@config_sources, ::Settings.instance_variable_get(:@config_sources).dup)
    end
  end

  private_class_method def self.settings_load(dump)
    Marshal.load(dump).tap do |settings|
      # Marshal dump of Settings loses the config_sources, so we need to restore manually
      settings.instance_variable_set(:@config_sources, dump.instance_variable_get(:@config_sources).dup)
    end
  end

  private_class_method def self.settings_changed?
    current = settings_dump

    # Marshal dump of Settings loses the config_sources, so we need to compare manually
    current != @settings_backup ||
      current.instance_variable_get(:@config_sources) != @settings_backup.instance_variable_get(:@config_sources)
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

  def self.stub_as_local_server(server)
    allow(MiqServer).to receive(:my_guid).and_return(server.guid)
    MiqServer.my_server_clear_cache
  end

  def self.local_miq_server(attrs = {})
    remote_miq_server(attrs).tap { |server| stub_as_local_server(server) }
  end

  def self.local_guid_miq_server_zone
    server = local_miq_server
    [server.guid, server, server.zone]
  end

  class << self
    alias_method :create_guid_miq_server_zone, :local_guid_miq_server_zone
  end

  def self.remote_miq_server(attrs = {})
    Tenant.root_tenant || Tenant.create!(:use_config_for_attributes => false)

    FactoryBot.create(:miq_server, attrs)
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

    root_file, other_files = MiqProductFeature.seed_files

    hashes = YAML.load_file(root_file)
    other_files.each do |f|
      hashes[:children] += Array.wrap(YAML.load_file(f))
    end

    filtered = filter_specific_features([hashes], features).first
    MiqProductFeature.seed_from_hash(filtered)
    MiqProductFeature.seed_tenant_miq_product_features
  end

  def self.filter_specific_features(hashes, features)
    hashes.select do |h|
      h[:children] = filter_specific_features(h[:children], features) if h[:children].present?
      h[:identifier].in?(features) || h[:children].present?
    end
  end
  private_class_method :filter_specific_features

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

  def self.import_yaml_model(dirname, domain, attrs = {})
    options = {'import_dir' => dirname, 'preview' => false, 'domain' => domain}
    yaml_import(domain, options, attrs)
  end

  def self.import_yaml_model_from_file(yaml_file, domain, attrs = {})
    options = {'yaml_file' => yaml_file, 'preview' => false, 'domain' => domain}
    yaml_import(domain, options, attrs)
  end

  def self.yaml_import(domain, options, attrs = {})
    Tenant.seed
    MiqAeImport.new(domain, options.merge('tenant' => Tenant.root_tenant)).import
    dom = MiqAeNamespace.lookup_by_fqname(domain)
    dom&.update(attrs.reverse_merge(:enabled => true))
  end
end

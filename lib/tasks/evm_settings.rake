module EvmSettings
  ALLOWED_KEYS ||= [
    "/authentication/sso_enabled",
    "/authentication/saml_enabled",
    "/authentication/oidc_enabled",
    "/authentication/provider_type",
    "/authentication/local_login_disabled"
  ].freeze

  INFO  ||= "info".freeze
  WARN  ||= "warn".freeze
  ERROR ||= "error".freeze

  def self.get_keys(keylist = nil)
    keylist = ALLOWED_KEYS if keylist.blank?
    settings_hash = Settings.to_hash
    keylist.each do |key|
      validate_key(key)
      value = settings_hash.fetch_path(*key_parts(key))
      puts "#{key}=#{value_to_str(value)}"
    end
  end

  def self.put_keys(keyval_list = nil)
    import_hash = {}
    Array(keyval_list).each do |keyval|
      key, value = keyval.split("=")
      validate_key(key)
      keyval_hash = keyval_to_hash(key, value)
      import_hash.deep_merge!(keyval_hash) if keyval_hash.present?
      log(INFO, "Setting key #{key} to #{value}")
      puts "#{key}=#{value}"
    end
    config_import(import_hash)
  end

  def self.config_import(import_hash)
    if import_hash.present?
      full_config_hash = MiqServer.my_server.settings
      MiqServer.my_server.add_settings_for_resource(
        full_config_hash.deep_merge(import_hash)
      )
    end
  end
  private_class_method :config_import

  def self.log(level, msg)
    $log.send(level, "EVM:Settings Task: #{msg}")
    STDERR.puts "#{level}: #{msg}" if level != INFO
  end
  private_class_method :log

  def self.supported_key?(key)
    ALLOWED_KEYS.include?(key)
  end
  private_class_method :supported_key?

  def self.validate_key(key)
    unless supported_key?(key)
      log(ERROR, "Unsupported key #{key} specified")
      exit(1)
    end
  end
  private_class_method :validate_key

  def self.key_parts(key)
    key.split("/")[1..-1].collect(&:to_sym)
  end
  private_class_method :key_parts

  def self.keyval_to_hash(key, value)
    hash = nil
    key_parts(key).reverse_each do |path|
      hash = {path => (hash.nil? ? str_to_value(value) : hash)}
    end
    hash
  end
  private_class_method :keyval_to_hash

  def self.str_to_value(value)
    return true  if value =~ /true/i
    return false if value =~ /false/i
    return nil   if value =~ /nil/
    value
  end
  private_class_method :str_to_value

  def self.value_to_str(value)
    return "true"  if value == true || value =~ /true/i
    return "false" if value == false || value =~ /false/i
    value
  end
  private_class_method :value_to_str
end

namespace :evm do
  namespace :settings do
    task :get => :environment do
      EvmSettings.get_keys $ARGV[1..-1]
      exit(0)
    end

    task :set => :environment do
      EvmSettings.put_keys $ARGV[1..-1]
      exit(0)
    end
  end
end

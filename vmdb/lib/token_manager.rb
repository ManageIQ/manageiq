require 'securerandom'

#
# Supporting class for Managing Tokens, i.e. Authentication Tokens for REST API, etc.
#
class TokenManager
  RESTRICTED_OPTIONS = [:expires_on]
  DEFAULT_NS         = "default"

  @token_caches = {}    # Hash of Memory/Dalli Store Caches, Keyed by namespace
  @config       = {:token_ttl => 10.minutes}    # Token expiration managed in seconds

  def initialize(*args)
    self.class.class_initialize(*args)
  end

  def self.class_initialize(name = DEFAULT_NS, options = {})
    configure(name, options)
  end

  def self.new(name = DEFAULT_NS, options = {})
    class_initialize(name, options)
    @instance ||= super
  end

  delegate :configure, :gen_token, :token_set_info, :token_get_info, :token_valid?, :to => self

  def self.configure(_namespace, options = {})
    @config.merge!(options)
  end

  def self.gen_token(namespace, token_options = {})
    ts = global_token_store(namespace)
    token = SecureRandom.hex(16)
    token_data = {:expires_on => Time.now.utc + @config[:token_ttl]}

    ts.write(token,
             token_data.merge!(prune_token_options(token_options)),
             :expires_in => @config[:token_ttl])
    token
  end

  def self.token_set_info(namespace, token, token_options = {})
    ts = global_token_store(namespace)
    token_data = ts.read(token)
    return {} if token_data.nil?

    ts.write(token, token_data.merge!(prune_token_options(token_options)))
  end

  def self.token_get_info(namespace, token, what = nil)
    ts = global_token_store(namespace)
    return {} unless token_valid?(namespace, token)

    what.nil? ? ts.read(token) : ts.read(token)[what]
  end

  def self.token_valid?(namespace, token)
    !global_token_store(namespace).read(token).nil?
  end

  private

  def self.global_token_store(namespace)
    @token_caches[namespace] ||= begin
      if test_environment?
        require 'active_support/cache/memory_store'
        ActiveSupport::Cache::MemoryStore.new(cache_store_options(namespace))
      else
        require 'active_support/cache/dalli_store'
        memcache_server = VMDB::Config.new("vmdb").config[:session][:memcache_server] || "127.0.0.1:11221"
        ActiveSupport::Cache::DalliStore.new(memcache_server, cache_store_options(namespace))
      end
    end
  end
  private_class_method :global_token_store

  def self.cache_store_options(namespace)
    {
      :namespace  => "MIQ:TOKENS:#{namespace.upcase}",
      :threadsafe => true,
      :expires_in => @config[:token_ttl]
    }
  end
  private_class_method :cache_store_options

  def self.test_environment?
    !Rails.env.development? && !Rails.env.production?
  end
  private_class_method :test_environment?

  def self.prune_token_options(token_options = {})
    token_options.except(*RESTRICTED_OPTIONS)
  end
  private_class_method :prune_token_options
end

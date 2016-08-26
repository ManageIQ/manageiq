require 'securerandom'

#
# Supporting class for Managing Tokens, i.e. Authentication Tokens for REST API, etc.
#
class TokenManager
  RESTRICTED_OPTIONS = [:expires_on]
  DEFAULT_NS         = "default"

  @config       = {:token_ttl => 10.minutes}    # Token expiration managed in seconds

  def initialize(namespace, options)
    @namespace = namespace
    @options = options
  end

  def self.new(namespace = DEFAULT_NS, options = {})
    class_initialize(options)
    super(namespace, @config)
  end

  delegate :gen_token, :reset_token, :token_set_info, :token_get_info, :token_valid?, :to => self

  def self.gen_token(namespace, token_options = {})
    ts = global_token_store(namespace)
    token = SecureRandom.hex(16)
    token_ttl_config = token_options.delete(:token_ttl_config)
    token_ttl = (token_ttl_config && @config[token_ttl_config]) ? @config[token_ttl_config] : @config[:token_ttl]
    token_data = {:token_ttl => token_ttl, :expires_on => Time.now.utc + token_ttl}

    ts.write(token,
             token_data.merge!(prune_token_options(token_options)),
             :expires_in => @config[:token_ttl])
    token
  end

  def self.reset_token(namespace, token)
    ts = global_token_store(namespace)
    token_data = ts.read(token)
    return {} if token_data.nil?

    token_ttl = token_data[:token_ttl]
    ts.write(token,
             token_data.merge!(:expires_on => Time.now.utc + token_ttl),
             :expires_in => token_ttl)
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

  def invalidate_token(token)
    token_store.delete(token)
  end

  private

  def token_store
    TokenStore.acquire(@namespace, @options[:token_ttl])
  end

  def self.class_initialize(options = {})
    @config.merge!(options)
  end
  private_class_method :class_initialize

  def self.global_token_store(namespace)
    TokenStore.acquire(namespace, @config[:token_ttl])
  end
  private_class_method :global_token_store

  def self.prune_token_options(token_options = {})
    token_options.except(*RESTRICTED_OPTIONS)
  end
  private_class_method :prune_token_options
end

require 'securerandom'
require 'action_dispatch/middleware/session/dalli_store'

#
# Supporting class for Managing Tokens, i.e. Authentication Tokens for REST API, etc.
#
class TokenManager
  RESTRICTED_OPTIONS = [:expires_on]
  DEFAULT_NS         = "default"

  # Token expiration managed in seconds via token_ttl option.
  @token_caches = {}    # Hash of memcache Dalli Clients, Keyed by namespace
  @config       = {:token_ttl => 10.minutes}

  def self.new(name = DEFAULT_NS, options = {})
    class_initialize(name, options)
    @instance ||= super
  end

  def self.class_initialize(name = DEFAULT_NS, options = {})
    configure(name, options)
  end

  def self.global_token_store(namespace)
    @token_caches[namespace] ||= begin
      memcache_server = VMDB::Config.new("vmdb").config[:session][:memcache_server] || "127.0.0.1:11221"
      Dalli::Client.new(memcache_server,
                        :namespace  => "MIQ:VMDB:TOKENS:#{namespace.upcase}",
                        :threadsafe => true,
                        :expires_in => @config[:token_ttl])
    end
  end

  def self.configure(_namespace, options = {})
    @config.merge!(options)
  end

  def self.gen_token(namespace, token_options = {})
    ts = global_token_store(namespace)
    token = SecureRandom.hex(16)
    token_data = {:expires_on => Time.now.tv_sec + @config[:token_ttl]}

    ts.add(token,
           token_data.merge!(prune_token_options(token_options)),
           @config[:token_ttl])
    token
  end

  def self.token_set_info(namespace, token, token_options = {})
    ts = global_token_store(namespace)
    token_data = ts.get(token)
    return {} if token_data.blank?

    ts.set(token, token_data.merge!(prune_token_options(token_options)))
  end

  def self.token_get_info(namespace, token, what = nil)
    ts = global_token_store(namespace)
    return {} unless token_valid?(namespace, token)

    what.nil? ? ts.get(token) : ts.get(token)[what]
  end

  def self.token_valid?(namespace, token)
    !global_token_store(namespace).get(token).nil?
  end

  def self.prune_token_options(token_options = {})
    token_options.except(*RESTRICTED_OPTIONS)
  end

  delegate :configure, :gen_token, :token_set_info, :token_get_info, :token_valid?, :to => self

  def initialize(*args)
    self.class.class_initialize(*args)
  end
end

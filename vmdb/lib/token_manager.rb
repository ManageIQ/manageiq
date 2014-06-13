require 'securerandom'

#
# Supporting class for Managing Tokens, i.e. Authentication Tokens for REST API, etc.
#
class TokenManager
  RESTRICTED_OPTIONS = [:expires_on]

  #
  # Token expiration all managed in seconds from epoch (using tv_sec)
  # Token check intervals and time-to-live are also in seconds
  #
  DEFAULT_NS = "default"
  @global_token_store          = {}    # Indexed by name
  @token_store_cleanup_lastrun = 0
  @config = {
    :token_ttl              => 10.minutes,
    :token_cleanup_interval => 2.minutes
  }

  def self.new(name = DEFAULT_NS, options = {})
    class_initialize(name, options)
    @instance ||= super
  end

  def self.class_initialize(name = DEFAULT_NS, options = {})
    configure(name, options)
  end

  def self.global_token_store(namespace)
    @global_token_store[namespace] ||= {}
  end

  def self.configure(_namespace, options = {})
    @config.merge!(options)
  end

  def self.gen_token(namespace, token_options = {})
    token_cleanup
    token = SecureRandom.hex(16)

    ts = global_token_store(namespace)
    ts[token] = {:expires_on => Time.now.tv_sec + @config[:token_ttl]}
    ts[token].merge!(prune_token_options(namespace, token, token_options))

    token
  end

  def self.token_set_info(namespace, token, token_options = {})
    ts = global_token_store(namespace)
    return {} unless ts.key?(token)
    ts[token].merge!(prune_token_options(namespace, token, token_options))
  end

  def self.token_get_info(namespace, token, what = nil)
    ts = global_token_store(namespace)
    return {} unless ts.key?(token)
    what.nil? ? ts[token] : ts[token][what]
  end

  def self.token_valid?(namespace, token)
    global_token_store(namespace).key?(token)
  end

  def self.token_expired?(namespace, token)
    return true unless token_valid?(namespace, token)

    ts = global_token_store(namespace)
    if ts[token][:expires_on] < Time.now.tv_sec
      log "#{namespace}:Expiring Token #{token}"
      ts.delete(token)
      return true
    end
    false
  end

  # Method to remove expired token
  def self.token_cleanup
    return if @config.nil?
    interval = @config[:token_cleanup_interval]
    # We only run the cleanup after a certain period of time
    thisrt = Time.now.tv_sec
    skipit = thisrt < (@token_store_cleanup_lastrun + interval)

    unless skipit
      @token_store_cleanup_lastrun = thisrt

      # Let's go over the current tokens and zap the expired ones
      @global_token_store.keys.each do |ns|
        ts = global_token_store(ns)
        ts.keys.each do |token|
          if ts[token][:expires_on] < Time.now.tv_sec
            log "#{ns}:Deleting Token #{token}"
            ts.delete(token)
          end
        end
      end
    end
  end

  delegate :configure, :gen_token, :token_set_info,
           :token_get_info, :token_valid?, :token_expired?,
           :token_cleanup, :to => self

  def initialize(*args)
    self.class.class_initialize(*args)
  end

  def self.prune_token_options(namespace, token, token_options = {})
    RESTRICTED_OPTIONS.each do |rto|
      if token_options.key?(rto)
        log "#{namespace}:Cannot set Restricted option #{rto} for token #{token}"
        token_options.delete(rto)
      end
    end
    token_options
  end

  def self.log(msg)
    match  = /`(?<mname>[^']*)'/.match(caller.first)
    method = (match ? match[:mname] : __method__).sub(/block .*in /, "")
    log_prefix = "#{self.class.name}.#{method}"
    if defined?($api_log.info)
      $api_log.info("MIQ(#{log_prefix}) #{msg}")
    else
      puts "#{log_prefix}: #{msg}"
    end
  end
end

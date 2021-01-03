require 'securerandom'

#
# Supporting class for Managing Tokens, i.e. Authentication Tokens for REST API, etc.
#
class TokenManager
  RESTRICTED_OPTIONS = [:expires_on]
  DEFAULT_NS         = "default"

  def initialize(namespace = DEFAULT_NS, options = {})
    @namespace = namespace
    @options = {:token_ttl => -> { 10.minutes }}.merge(options)
  end

  def gen_token(token_options = {})
    token = SecureRandom.hex(16)
    ttl = token_options.delete(:token_ttl_override) || token_ttl
    token_data = {:token_ttl => ttl, :expires_on => Time.now.utc + ttl}

    token_store.create_user_token(token,
                                  token_data.merge!(prune_token_options(token_options)),
                                  :expires_in => token_ttl)
    token
  end

  def reset_token(token)
    token_data = token_store.read(token)
    return {} if token_data.nil?

    ttl = token_data[:token_ttl]
    token_data[:expires_on] = Time.now.utc + ttl
    token_store.write(token,
                      token_data,
                      :expires_in => ttl)
  end

  def token_get_info(token, what = nil)
    return {} unless token_valid?(token)

    token_data = token_store.read(token)
    return nil if token_data.nil?

    what.nil? ? token_data : token_data[what]
  end

  def token_valid?(token)
    !token_store.read(token).nil?
  end

  def invalidate_token(token)
    token_store.delete(token)
  end

  def token_ttl
    @options[:token_ttl].call
  end

  private

  def token_store
    TokenStore.acquire(@namespace, token_ttl)
  end

  def prune_token_options(token_options = {})
    token_options.except(*RESTRICTED_OPTIONS)
  end
end

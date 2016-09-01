require 'securerandom'

#
# Supporting class for Managing Tokens, i.e. Authentication Tokens for REST API, etc.
#
class TokenManager
  RESTRICTED_OPTIONS = [:expires_on]
  DEFAULT_NS         = "default"

  def initialize(namespace = DEFAULT_NS, options = {})
    @namespace = namespace
    @options = {:token_ttl => 10.minutes}.merge(options)
  end

  def gen_token(token_options = {})
    token = SecureRandom.hex(16)
    token_ttl = token_options.delete(:token_ttl_override) || @options[:token_ttl]
    token_data = {:token_ttl => token_ttl, :expires_on => Time.now.utc + token_ttl}

    token_store.write(token,
                      token_data.merge!(prune_token_options(token_options)),
                      :expires_in => @options[:token_ttl])
    token
  end

  def reset_token(token)
    token_data = token_store.read(token)
    return {} if token_data.nil?

    token_ttl = token_data[:token_ttl]
    token_store.write(token,
                      token_data.merge!(:expires_on => Time.now.utc + token_ttl),
                      :expires_in => token_ttl)
  end

  def token_get_info(token, what = nil)
    return {} unless token_valid?(token)

    what.nil? ? token_store.read(token) : token_store.read(token)[what]
  end

  def token_valid?(token)
    !token_store.read(token).nil?
  end

  def invalidate_token(token)
    token_store.delete(token)
  end

  private

  def token_store
    TokenStore.acquire(@namespace, @options[:token_ttl])
  end

  def prune_token_options(token_options = {})
    token_options.except(*RESTRICTED_OPTIONS)
  end
end

#
# CloudForms Management Engine REST API Client
#
#
require 'rack'
require 'faraday'
require 'faraday_middleware'
require 'uri'
require 'active_support/all'
require 'more_core_extensions/all'

require 'cfme_client/net'

class CfmeClient
  DEFAULT_CONFIG = {
    :scheme       => 'http',
    :host         => 'localhost',
    :port         => 3000,
    :prefix       => '/api',
    :version      => nil,
    :open_timeout => 5,
    :content_type => 'application/json',
    :accept       => 'application/json',
    :debug        => false
  }

  DEFAULT_OPTIONS = {
    :user     => "",
    :password => "",
    :headers  => {}
  }

  API_STATUS = Rack::Utils::HTTP_STATUS_CODES.merge(0 => "Network Connection Error")

  def initialize(options = {})
    @config        = DEFAULT_CONFIG.dup
    @params_user   = [:user, :password]
    @params_config = DEFAULT_CONFIG.keys
    @options       = DEFAULT_OPTIONS.dup

    update_options(options)
    @code, @status, @message, @result = [200, API_STATUS[200], "", {}]
  end

  def configure(options = {})
    update_options(options)
  end

  def update_options(updates = {})
    # Let's get any configuration updates
    #
    update_options_url(updates)
    update_options_config(updates)
    update_options_user_password(updates)
    update_options_token(updates)

    # All others are header options
    @options[:headers].merge!(updates)
  end

  #
  # API's
  #
  def entrypoint(options = {})
    configure(options)
    resource_method(:get)
  end

  def authenticate(options = {})
    configure(options)
    resource_method(:get, "/auth")
  end

  #
  # Accessor Functions
  #
  #   Need API Caller to have access to :code, :status, :message and :result
  #
  def code
    @code     ||= ""
  end

  def status
    @status   ||= ""
  end

  def message
    @message  ||= ""
  end

  def result
    @result   ||= {}
  end

  private

  def update_options_url(updates)
    # If :url is specified, let's parse that into :scheme, :host and :port
    if updates.key?(:url)
      uri = URI.parse(updates[:url])
      @config[:scheme] = uri.scheme || DEFAULT_CONFIG[:scheme]
      @config[:host]   = uri.host   || DEFAULT_CONFIG[:host]
      @config[:port]   = uri.port   || DEFAULT_CONFIG[:port]
      updates.delete(:url)
    end
  end

  def update_options_config(updates)
    # Let's get any other config parameters specified
    @params_config.each do |k|
      if updates.key?(k)
        @config[k] = updates[k]
        updates.delete(k)
      end
    end
  end

  def update_options_user_password(updates)
    # User/Password Basic Authentication
    if updates.key?(:user) || updates.key?(:password)
      @options[:user]     = updates[:user] || ""
      @options[:password] = updates[:password] || ""
      @options[:headers].delete(:x_auth_token)
      @params_user.each { |k| updates.delete(k) }
    end
  end

  def update_options_token(updates)
    # Token Based Authentication
    if updates.key?(:auth_token)
      @options[:headers][:x_auth_token] = updates[:auth_token]
      @params_user.each { |k| @options.delete(k) }
      updates.delete(:auth_token)
    end
  end
end

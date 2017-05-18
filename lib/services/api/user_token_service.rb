module Api
  class UserTokenService
    TYPES = %w(api ui ws).freeze
    # Additional Requester type token ttl's for authentication
    TYPE_TO_TTL_OVERRIDE = {'ui' => ::Settings.session.timeout}.freeze

    def initialize(config = ApiConfig, args = {})
      @config = config
      @svc_options = args
    end

    def token_mgr(type)
      @token_mgr ||= {}
      case type
      when 'api', 'ui' # The default API token and UI token share the same TokenStore
        @token_mgr['api'] ||= new_token_mgr(base_config[:module], base_config[:name], api_config)
      when 'ws'
        @token_mgr['ws'] ||= TokenManager.new('ws', :token_ttl => ::Settings.session.timeout)
      end
    end

    # API Settings with additional token ttl's
    #
    def api_config
      @api_config ||= ::Settings[base_config[:module]].to_hash
    end

    def generate_token(userid, requester_type)
      validate_userid(userid)
      validate_requester_type(requester_type)

      $api_log.info("Generating Authentication Token for userid: #{userid} requester_type: #{requester_type}")

      token_mgr(requester_type).gen_token(:userid             => userid,
                                          :token_ttl_override => TYPE_TO_TTL_OVERRIDE[requester_type])
    end

    def validate_requester_type(requester_type)
      return if TYPES.include?(requester_type)
      requester_types = TYPES.join(', ')
      raise "Invalid requester_type #{requester_type} specified, valid types are: #{requester_types}"
    end

    private

    def base_config
      @config[:base]
    end

    def log_kv(key, val, pref = "")
      $api_log.info("#{pref}  #{key.to_s.ljust([24, key.to_s.length].max, ' ')}: #{val}")
    end

    def new_token_mgr(mod, name, api_config)
      token_ttl = api_config[:token_ttl]

      options                = {}
      options[:token_ttl]    = token_ttl.to_i_with_method if token_ttl

      log_init(mod, name, options) if @svc_options[:log_init]
      TokenManager.new(mod, options)
    end

    def log_init(mod, name, options)
      $api_log.info("")
      $api_log.info("Creating new Token Manager for the #{name}")
      $api_log.info("   Token Manager  module: #{mod}")
      $api_log.info("   Token Manager options:")
      options.each { |key, val| log_kv(key, val, "    ") }
      $api_log.info("")
    end

    def validate_userid(userid)
      raise "Invalid userid #{userid} specified" unless User.exists?(:userid => userid)
    end
  end
end

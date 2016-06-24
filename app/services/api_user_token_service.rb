class ApiUserTokenService
  def initialize(config = Api::Settings.data, args = {})
    @config = config
    @svc_options = args
    @token_mgr = new_token_mgr(base_config[:module], base_config[:name], api_config)
  end

  attr_accessor :token_mgr

  # Additional Requester type token ttl's for authentication
  #
  REQUESTER_TTL_CONFIG = {"ui" => :ui_token_ttl}.freeze

  # API Settings with additional token ttl's
  #
  def api_config
    @api_config ||= Settings[base_config[:module]].to_hash.merge(
      REQUESTER_TTL_CONFIG["ui"] => Settings.session.timeout
    )
  end

  def generate_token(userid, requester_type)
    validate_userid(userid)
    validate_requester_type(requester_type)

    $api_log.info("Generating Authentication Token for userid: #{userid} requester_type: #{requester_type}")

    token_mgr.gen_token(base_config[:module],
                        :userid           => userid,
                        :token_ttl_config => REQUESTER_TTL_CONFIG[requester_type])
  end

  def validate_requester_type(requester_type)
    return unless requester_type
    REQUESTER_TTL_CONFIG.fetch(requester_type) do
      requester_types = REQUESTER_TTL_CONFIG.keys.join(', ')
      raise "Invalid requester_type #{requester_type} specified, valid types are: #{requester_types}"
    end
  end

  private

  def base_config
    @config[:base]
  end

  def log_kv(key, val, pref = "")
    $api_log.info("#{pref}  #{key.to_s.ljust([24, key.to_s.length].max, ' ')}: #{val}")
  end

  def new_token_mgr(mod, name, api_config)
    token_ttl    = api_config[:token_ttl]
    ui_token_ttl = api_config[REQUESTER_TTL_CONFIG["ui"]]

    options                = {}
    options[:token_ttl]    = token_ttl.to_i_with_method if token_ttl
    options[:ui_token_ttl] = ui_token_ttl.to_i_with_method if ui_token_ttl

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

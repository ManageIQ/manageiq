require 'Amazon/amazon_iam'

class AmazonAuth
  def self.validate_connection(config)
    errors = {}

    auth = config[:authentication]
    begin
      amazon_auth = AmazonAuth.new(:auth=>auth)
      result = amazon_auth.admin_connect
    rescue Exception => err
      result = false
      errors[[:authentication, auth[:mode]].join("_")] = err.message
    else
      errors[[:authentication, auth[:mode]].join("_")] = "Authentication failed" unless result
    end

    return result, errors
  end

  def initialize(options = {})
    log_prefix = "MIQ(AmazonAuth.initialize)"
    @auth = options[:auth] || VMDB::Config.new("vmdb").config[:authentication]
    log_auth = VMDB::Config.clone_auth_for_log(@auth)
    $log.info("#{log_prefix} Server Settings: #{log_auth.inspect}")
    mode           = options.delete(:mode)          || @auth[:mode]
    @amazon_key    = options.delete(:amazon_key)    || @auth[:amazon_key]
    @amazon_secret = options.delete(:amazon_secret) || @auth[:amazon_secret]

  end

  def self.using_iam_authentication?
    VMDB::Config.new("vmdb").config[:authentication][:mode].include?('iam')
  end

  def iam_authenticate(username, password)
    log_prefix = "MIQ(AmazonAuth.iam_authenticate)"
    $log.info("#{log_prefix} Verifying IAM User: [#{username}]...")
    begin
      iam = admin_connect
      AmazonIam.verify_iam_user(username, password, iam)
      #fixme should we do this here, or just propagate exception?
      # following MiqLdap.bind for now
    rescue Exception => err
      $log.error("#{log_prefix} Verifying IAM User: [#{username}], '#{err.message}'")
      return false
    end
  end

  def admin_connect
    @admin_iam ||= AmazonIam.iam_for_aws_user(@amazon_key, @amazon_secret)
  end

  def iam_user(username)
    AmazonIam.iam_user_for_access_key(admin_connect, username)
  end

  def get_memberships(user)
    user.groups.collect(&:name)
  end
end

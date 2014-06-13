
class AmazonConnection

  def self.raw_connect(access_key_id, secret_access_key, service = "EC2", region = nil, proxy_uri = nil)
    require 'aws-sdk'
    AWS.config(
      :logger        => $aws_log,
      :log_level     => :debug,
      :log_formatter => AWS::Core::LogFormatter.new(AWS::Core::LogFormatter.default.pattern.chomp)
    )

    params = {:access_key_id => access_key_id, :secret_access_key => secret_access_key}
    params[:region]    = region    if region
    params[:proxy_uri] = proxy_uri if proxy_uri
    AWS.const_get(service).new(params)
  end

  def self.verify_credentials(access_key_id, secret_access_key)
    begin
      self.raw_connect(access_key_id, secret_access_key).regions.map(&:name)
    rescue AWS::EC2::Errors::SignatureDoesNotMatch => err
      raise MiqException::MiqHostError, "SignatureMismatch - check your AWS Secret Access Key and signing method"
    rescue AWS::EC2::Errors::AuthFailure => err
      raise MiqException::MiqHostError, "Login failed due to a bad username or password."
    rescue AWS::EC2::Errors::UnauthorizedOperation => err
      # user unauthorized for ec2, but still a valid IAM login
      return true
    rescue Exception => err
      $log.error("MIQ(#{self.class.name}.verify_credentials) Error Class=#{err.class.name}, Message=#{err.message}")
      raise MiqException::MiqHostError, "Unexpected response returned from system, see log for details"
    end
    return true
  end
end

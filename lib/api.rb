module Api
  def self.normalized_attributes
    @normalized_attributes ||= {:time => {}, :url => {}, :resource => {}, :encrypted => {}}
  end

  def self.user_token_service
    @user_token_service ||= ApiUserTokenService.new(Api::Settings, :log_init => true)
  end
end

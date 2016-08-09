module Api
  def self.normalized_attributes
    @normalized_attributes ||= {:time => {}, :url => {}, :resource => {}, :encrypted => {}}
  end

  def self.user_token_service
    @user_token_service ||= ApiUserTokenService.new(Api::Settings, :log_init => true)
  end

  def self.fetch_encrypted_attribute_names(klass)
    return [] unless klass.respond_to?(:encrypted_columns)
    encrypted_objects_checked[klass.name] ||= klass.encrypted_columns.each do |attr|
      Api.normalized_attributes[:encrypted][attr] = true
    end
  end

  def self.encrypted_objects_checked
    @encrypted_objects_checked ||= {}
  end
end

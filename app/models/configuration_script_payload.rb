class ConfigurationScriptPayload < ConfigurationScriptBase
  acts_as_miq_taggable

  belongs_to :configuration_script_source

  validate :validate_credentials_payload, :if => :credentials_changed?

  def self.base_model
    ConfigurationScriptPayload
  end

  def run(*)
    raise NotImplementedError, _("run must be implemented in a subclass")
  end

  def validate_credentials_payload
    return if credentials.blank?

    error   = "credentials must be a hash" unless credentials.kind_of?(Hash)
    error ||= credentials.each_value.collect do |val|
      if val.kind_of?(Hash)
        "credential value must have credential_ref and credential_field" unless val.key?("credential_ref") && val.key?("credential_field")
      elsif !val.kind_of?(String)
        "credential value must be string or a hash"
      end
    end.compact.first

    errors.add(:credentials, N_("Invalid payload: %{error}") % {:error => error}) if error
  end
end

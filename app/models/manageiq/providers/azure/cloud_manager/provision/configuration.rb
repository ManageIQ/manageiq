module ManageIQ::Providers::Azure::CloudManager::Provision::Configuration
  def userdata_payload
    return unless raw_script = super
    Base64.encode64(raw_script)
  end
end

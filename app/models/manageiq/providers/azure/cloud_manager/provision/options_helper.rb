module ManageIQ::Providers::Azure::CloudManager::Provision::OptionsHelper
  def root_password
    MiqPassword.decrypt(options[:root_password]) if options[:root_password]
  end

  def resource_group
    ResourceGroup.find_by(:id => options[:resource_group]).name
  end
end

module ManageIQ::Providers::CloudManager::AuthKeyPair::Operations
  extend ActiveSupport::Concern

  def raw_delete_key_pair
    raise NotImplementedError, _("raw_delete_key_pair must be implemented in a subclass")
  end

  class_methods do
    def raw_create_key_pair(_ext_management_system, _options = {})
      raise NotImplementedError, "raw_create_key_pair must be implemented in a subclass"
    end
  end
end

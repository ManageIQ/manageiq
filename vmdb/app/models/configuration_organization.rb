class ConfigurationOrganization < ActiveRecord::Base
  belongs_to :provisioning_manager

  alias_attribute :display_name, :title
end

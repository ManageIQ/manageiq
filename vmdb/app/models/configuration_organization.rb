class ConfigurationOrganization < ActiveRecord::Base
  belongs_to :provisioning_manager
  belongs_to :parent, :class_name => 'ConfigurationOrganization'

  alias_attribute :display_name, :title
end

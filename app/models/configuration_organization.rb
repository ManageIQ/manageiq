class ConfigurationOrganization < ApplicationRecord
  belongs_to :provisioning_manager
  belongs_to :parent, :class_name => 'ConfigurationOrganization'
  has_and_belongs_to_many :configuration_profiles, :join_table => :configuration_organizations_configuration_profiles

  alias_attribute :display_name, :title

  def path
    (parent.try(:path) || []).push(self)
  end
end

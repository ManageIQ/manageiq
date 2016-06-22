class NamespaceEmsForeman < ActiveRecord::Migration
  include MigrationHelper

  NAME_MAP = Hash[*%w(
    ConfigurationManager                        ManageIQ::Providers::ConfigurationManager
    ProvisioningManager                         ManageIQ::Providers::ProvisioningManager

    ProviderForeman                             ManageIQ::Providers::Foreman::Provider
    ConfigurationManagerForeman                 ManageIQ::Providers::Foreman::ConfigurationManager
    ConfigurationProfileForeman                 ManageIQ::Providers::Foreman::ConfigurationManager::ConfigurationProfile
    ConfiguredSystemForeman                     ManageIQ::Providers::Foreman::ConfigurationManager::ConfiguredSystem
    MiqProvisionConfiguredSystemForemanWorkflow ManageIQ::Providers::Foreman::ConfigurationManager::ProvisionWorkflow
    MiqProvisionTaskConfiguredSystemForeman     ManageIQ::Providers::Foreman::ConfigurationManager::ProvisionTask
    ProvisioningManagerForeman                  ManageIQ::Providers::Foreman::ProvisioningManager
  )]

  def change
    rename_class_references(NAME_MAP)
  end
end

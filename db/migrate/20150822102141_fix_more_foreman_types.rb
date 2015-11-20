class FixMoreForemanTypes < ActiveRecord::Migration
  include MigrationHelper

  NAME_MAP = Hash[*%w(
    ConfigurationProfileForeman        ManageIQ::Providers::Foreman::ConfigurationManager::ConfigurationProfile
    ConfiguredSystemForeman            ManageIQ::Providers::Foreman::ConfigurationManager::ConfiguredSystem
  )]

  def change
    say_with_time "Rename class references for Foreman" do
      rename_class_references(NAME_MAP)
    end
  end
end

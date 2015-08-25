class FixForemanProviderType < ActiveRecord::Migration
  include MigrationHelper

  NAME_MAP = Hash[*%w(
    ProviderForeman                    ManageIQ::Providers::Foreman::Provider
  )]

  def change
    rename_class_references(NAME_MAP)
  end
end

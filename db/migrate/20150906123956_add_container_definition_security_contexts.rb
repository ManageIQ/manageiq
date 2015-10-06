class AddContainerDefinitionSecurityContexts < ActiveRecord::Migration
  def change
    add_column    :container_definitions, :privileged, :boolean
    add_column    :container_definitions, :run_as_user, :bigint
    add_column    :container_definitions, :run_as_non_root, :boolean
    add_column    :container_definitions, :capabilities_add, :string
    add_column    :container_definitions, :capabilities_drop, :string
  end
end

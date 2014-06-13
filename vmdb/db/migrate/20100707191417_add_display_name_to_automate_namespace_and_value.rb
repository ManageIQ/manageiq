class AddDisplayNameToAutomateNamespaceAndValue < ActiveRecord::Migration
  def self.up
    add_column    :miq_ae_namespaces,    :display_name,        :string
    add_column    :miq_ae_values,        :display_name,        :string
  end

  def self.down
    remove_column :miq_ae_namespaces,    :display_name
    remove_column :miq_ae_values,        :display_name
  end
end

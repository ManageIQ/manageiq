class AddEnabledToMiqAeNamespaces < ActiveRecord::Migration
  def change
    add_column :miq_ae_namespaces, :enabled, :boolean
  end
end

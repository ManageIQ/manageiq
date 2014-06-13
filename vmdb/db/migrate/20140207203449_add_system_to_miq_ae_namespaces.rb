class AddSystemToMiqAeNamespaces < ActiveRecord::Migration
  def change
    add_column :miq_ae_namespaces, :system, :boolean
  end
end

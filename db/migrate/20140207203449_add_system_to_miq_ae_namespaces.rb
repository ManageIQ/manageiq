class AddSystemToMiqAeNamespaces < ActiveRecord::Migration[4.2]
  def change
    add_column :miq_ae_namespaces, :system, :boolean
  end
end

class AddTopLevelNamespaceToMiqAeNamespaces < ActiveRecord::Migration[5.0]
  def change
    add_column :miq_ae_namespaces, :top_level_namespace, :string
  end
end

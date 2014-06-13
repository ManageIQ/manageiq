class AddPriorityToMiqAeNamespaces < ActiveRecord::Migration
  def change
    add_column :miq_ae_namespaces, :priority, :integer
  end
end

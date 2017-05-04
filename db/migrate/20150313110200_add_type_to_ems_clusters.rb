class AddTypeToEmsClusters < ActiveRecord::Migration[4.2]
  def change
    add_column :ems_clusters, :type, :string
  end
end

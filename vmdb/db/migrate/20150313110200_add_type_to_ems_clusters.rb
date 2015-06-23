class AddTypeToEmsClusters < ActiveRecord::Migration
  def change
    add_column :ems_clusters, :type, :string
  end
end

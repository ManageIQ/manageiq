class RemoveUpdateRepoNameFromMiqDatabases < ActiveRecord::Migration[5.0]
  def change
    remove_column :miq_databases, :update_repo_name, :string
  end
end

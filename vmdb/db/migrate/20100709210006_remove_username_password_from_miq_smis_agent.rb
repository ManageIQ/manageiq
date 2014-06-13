class RemoveUsernamePasswordFromMiqSmisAgent < ActiveRecord::Migration
  def self.up
    remove_column :miq_smis_agents, :username
    remove_column :miq_smis_agents, :password
  end

  def self.down
    add_column :miq_smis_agents, :username, :string
    add_column :miq_smis_agents, :password, :string
  end
end

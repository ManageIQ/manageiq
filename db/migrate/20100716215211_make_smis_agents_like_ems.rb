class MakeSmisAgentsLikeEms < ActiveRecord::Migration
  def self.up
    rename_column :miq_smis_agents, :server, :ipaddress
    add_column :miq_smis_agents, :name, :string
    add_column :miq_smis_agents, :hostname, :string
    add_column :miq_smis_agents, :port, :string
  end

  def self.down
    rename_column :miq_smis_agents, :ipaddress, :server
    remove_column :miq_smis_agents, :name
    remove_column :miq_smis_agents, :hostname
    remove_column :miq_smis_agents, :port
  end
end

class CreateMiqSmisAgents < ActiveRecord::Migration
  def self.up
    create_table :miq_smis_agents do |t|
      t.column :server,       :string
      t.column :username,       :string
      t.column :password,       :string
      t.column :agent_type,     :string
      t.column :last_update_status, :integer
      t.timestamps
    end
  end

  def self.down
    drop_table :miq_smis_agents
  end
end

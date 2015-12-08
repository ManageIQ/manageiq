class RemoveConfigurations < ActiveRecord::Migration
  def up
    drop_table :configurations
  end

  def down
    create_table :configurations do |t|
      t.belongs_to :miq_server, :type => :bigint
      t.string     :typ
      t.text       :settings
      t.datetime   :created_on
      t.datetime   :updated_on
    end
    add_index :configurations, :miq_server_id
  end
end

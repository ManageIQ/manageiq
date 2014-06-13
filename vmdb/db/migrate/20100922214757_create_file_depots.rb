class CreateFileDepots < ActiveRecord::Migration
  def self.up
    create_table :file_depots do |t|
      t.string      :name
      t.integer     :resource_id
      t.string      :resource_type
      t.string      :uri
      t.timestamps
    end
  end

  def self.down
    drop_table :file_depots
  end
end

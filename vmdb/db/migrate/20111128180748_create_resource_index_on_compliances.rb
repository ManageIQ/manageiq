class CreateResourceIndexOnCompliances < ActiveRecord::Migration
  def self.up
    add_index    :compliances, [:resource_id, :resource_type]
  end

  def self.down
    remove_index :compliances, [:resource_id, :resource_type]
  end
end

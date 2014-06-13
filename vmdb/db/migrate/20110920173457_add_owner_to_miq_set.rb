class AddOwnerToMiqSet < ActiveRecord::Migration
  def self.up
    add_column    :miq_sets, :owner_type, :string
    add_column    :miq_sets, :owner_id,   :bigint
  end

  def self.down
    remove_column :miq_sets, :owner_type
    remove_column :miq_sets, :owner_id
  end
end

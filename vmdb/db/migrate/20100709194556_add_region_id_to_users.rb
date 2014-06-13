class AddRegionIdToUsers < ActiveRecord::Migration
  class MiqRegion < ActiveRecord::Base; end
  class User < ActiveRecord::Base; end

  def self.up
    remove_index :users, :userid
    add_column   :users, :region, :integer
    add_index    :users, [:userid, :region], :unique => true

    say_with_time("Update User region") do
      User.all.each { |u| u.update_attribute(:region, MiqRegion.id_to_region(u.id)) }
    end
  end

  def self.down
    remove_index  :users, [:userid, :region]
    remove_column :users, :region
    add_index     :users, :userid, :unique => true
  end
end

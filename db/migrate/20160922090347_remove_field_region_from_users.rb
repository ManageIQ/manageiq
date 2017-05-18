class RemoveFieldRegionFromUsers < ActiveRecord::Migration[5.0]
  def change
    remove_index :users, :column => [:userid, :region],
                         :name   => :index_users_on_userid_and_region,
                         :unique => true
    add_index :users, [:userid], :name => :index_users_on_userid
    remove_column :users, :region, :integer
  end
end

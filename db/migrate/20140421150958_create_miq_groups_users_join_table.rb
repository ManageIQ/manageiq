class CreateMiqGroupsUsersJoinTable < ActiveRecord::Migration
  class MiqGroupsUsers < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
    self.primary_key = nil
  end

  class User < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
    include ReservedMixin
    include MigrationStubHelper # NOTE: Must be included after other mixins
  end

  def up
    create_table :miq_groups_users, :id => false do |t|
      t.bigint :miq_group_id
      t.bigint :user_id
    end

    say_with_time("Migrate eligible_miq_group_ids from reserved column") do
      User.includes(:reserved_rec).each do |u|
        group_ids = u.reserved_hash_get(:eligible_miq_group_ids)
        next if group_ids.nil?

        u.reserved_hash_set(:eligible_miq_group_ids, nil)
        u.save!

        group_ids.each do |gid|
          MiqGroupsUsers.create!(:miq_group_id => gid, :user_id => u.id)
        end
      end
    end

    add_index :miq_groups_users, [:user_id, :miq_group_id], :unique => true
  end

  def down
    remove_index :miq_groups_users, [:user_id, :miq_group_id]
    drop_table :miq_groups_users
  end
end

class AddVappToResourcePool < ActiveRecord::Migration
  class ResourcePool < ActiveRecord::Base
    include ReservedMixin
    include MigrationStubHelper # NOTE: Must be included after other mixins
  end

  def self.up
    add_column :resource_pools, :vapp, :boolean

    say_with_time("Migrate data from reserved table") do
      ResourcePool.includes(:reserved_rec).each do |rp|
        rp.reserved_hash_migrate(:vapp)
      end
    end
  end

  def self.down
    remove_column :resource_pools, :vapp
  end
end

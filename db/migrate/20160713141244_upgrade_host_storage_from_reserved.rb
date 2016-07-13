class UpgradeHostStorageFromReserved < ActiveRecord::Migration[5.0]
  class HostStorage < ActiveRecord::Base
    include ReservedMixin
    include MigrationStubHelper
  end

  def up
    say_with_time("Migrate data from reserved table to host_storages") do
      HostStorage.includes(:reserved_rec).each do |hs|
        hs.reserved_hash_migrate(:ems_ref)
      end
    end
  end

  def down
    say_with_time("Migrate data from host_storages to reserved table") do
      HostStorage.includes(:reserved_rec).each do |hs|
        hs.reserved_hash_set(:ems_ref, hs.ems_ref)
        hs.save!
      end
    end
  end
end

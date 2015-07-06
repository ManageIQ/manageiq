class AddApiVersionAndUidEmsToExtManagementSystems < ActiveRecord::Migration
  class ExtManagementSystem < ActiveRecord::Base
    include ReservedMixin
    include MigrationStubHelper # NOTE: Must be included after other mixins
  end

  def self.up
    add_column :ext_management_systems, :api_version, :string
    add_column :ext_management_systems, :uid_ems,     :string

    say_with_time("Migrate data from reserved table") do
      ExtManagementSystem.includes(:reserved_rec).each do |e|
        e.reserved_hash_migrate(:api_version, :uid_ems)
      end
    end
  end

  def self.down
    remove_column :ext_management_systems, :api_version
    remove_column :ext_management_systems, :uid_ems
  end
end

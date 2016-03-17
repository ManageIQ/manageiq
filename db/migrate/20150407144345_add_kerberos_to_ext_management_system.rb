class AddKerberosToExtManagementSystem < ActiveRecord::Migration
  class ExtManagementSystem < ActiveRecord::Base
    self.inheritance_column = :_type_disabled

    include ReservedMixin
    include MigrationStubHelper # NOTE: Must be included after other mixins
  end

  def self.up
    add_column :ext_management_systems, :security_protocol, :string
    add_column :ext_management_systems, :realm, :string

    say_with_time("Migrate data from reserved table") do
      ExtManagementSystem.includes(:reserved_rec).each do |e|
        e.reserved_hash_migrate(:security_protocol, :realm)
      end
    end
  end

  def down
    say_with_time("Migrating security_protocol and realm to Reserves table") do
      ExtManagementSystem.includes(:reserved_rec).each do |e|
        e.reserved_hash_set(:security_protocol, e.security_protocol)
        e.reserved_hash_set(:realm, e.realm)
        e.save!
      end
    end

    remove_column :ext_management_systems, :security_protocol
    remove_column :ext_management_systems, :realm
  end
end

class MigrateMiqDatabaseRegistrationOrganizationDisplayNameOutOfReserves < ActiveRecord::Migration
  class MiqDatabase < ActiveRecord::Base
    include ReservedMixin
    include MigrationStubHelper # NOTE: Must be included after other mixins
  end

  def up
    add_column :miq_databases, :registration_organization_display_name, :string

    say_with_time("Migrate registration_organization_display_name from reserved table") do
      MiqDatabase.includes(:reserved_rec).each do |db|
        db.reserved_hash_migrate(:registration_organization_display_name)
      end
    end
  end

  def down
    say_with_time("Migrating registration_organization_display_name to Reserves table") do
      MiqDatabase.includes(:reserved_rec).each do |d|
        d.reserved_hash_set(:registration_organization_display_name, d.registration_organization_display_name)
        d.save!
      end
    end

    remove_column :miq_databases, :registration_organization_display_name
  end
end

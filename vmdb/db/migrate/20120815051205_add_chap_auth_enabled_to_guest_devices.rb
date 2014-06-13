class AddChapAuthEnabledToGuestDevices < ActiveRecord::Migration
  class GuestDevice < ActiveRecord::Base
    include ReservedMixin
    include MigrationStubHelper # NOTE: Must be included after other mixins
  end

  def up
    add_column :guest_devices, :chap_auth_enabled, :boolean

    say_with_time("Migrate data from reserved table") do
      GuestDevice.includes(:reserved_rec).each do |gd|
        gd.reserved_hash_migrate(:chap_auth_enabled)
      end
    end
  end

  def down
    remove_column :guest_devices, :chap_auth_enabled
  end
end

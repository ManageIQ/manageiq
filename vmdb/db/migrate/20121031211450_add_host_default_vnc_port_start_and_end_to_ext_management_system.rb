class AddHostDefaultVncPortStartAndEndToExtManagementSystem < ActiveRecord::Migration
  class ExtManagementSystem < ActiveRecord::Base
    include ReservedMixin
    include MigrationStubHelper # NOTE: Must be included after other mixins
  end

  def up
    add_column :ext_management_systems, :host_default_vnc_port_start, :integer
    add_column :ext_management_systems, :host_default_vnc_port_end,   :integer

    say_with_time("Migrate data from reserved table") do
      ExtManagementSystem.includes(:reserved_rec).each do |e|
        e.reserved_hash_migrate(:host_default_vnc_port_start, :host_default_vnc_port_end)
      end
    end
  end

  def down
    remove_column :ext_management_systems, :host_default_vnc_port_start
    remove_column :ext_management_systems, :host_default_vnc_port_end
  end
end

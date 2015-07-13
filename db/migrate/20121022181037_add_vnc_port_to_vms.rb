class AddVncPortToVms < ActiveRecord::Migration
  class Vm < ActiveRecord::Base
    include ReservedMixin
    include MigrationStubHelper # NOTE: Must be included after other mixins
  end

  def up
    add_column :vms, :vnc_port, :integer

    say_with_time("Migrate data from reserved table") do
      Vm.includes(:reserved_rec).each do |v|
        v.reserved_hash_migrate(:vnc_port)
      end
    end
  end

  def down
    remove_column :vms, :vnc_port
  end
end

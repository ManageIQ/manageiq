class AddLinkedCloneAndFaultToleranceToVms < ActiveRecord::Migration
  class Vm < ActiveRecord::Base
    include ReservedMixin
    include MigrationStubHelper # NOTE: Must be included after other mixins
  end

  def self.up
    add_column :vms, :linked_clone,    :boolean
    add_column :vms, :fault_tolerance, :boolean

    say_with_time("Migrate data from reserved table") do
      Vm.all.each do |v|
        v.reserved_hash_migrate(:linked_clone, :fault_tolerance)
      end
    end
  end

  def self.down
    remove_column :vms, :linked_clone
    remove_column :vms, :fault_tolerance
  end
end

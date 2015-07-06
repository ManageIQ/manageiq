class DeserializeRetirementFromVms < ActiveRecord::Migration
  class Vm < ActiveRecord::Base
    self.inheritance_column = :_type_disabled    # disable STI
    serialize :retirement
  end

  def up
    add_column :vms, :retirement_warn,      :bigint
    add_column :vms, :retirement_last_warn, :datetime

    say_with_time("Migrating VM Retirement Information") do
      Vm.all.each do |vm|
        next if vm.retirement.blank?

        vm.update_attributes(
          :retirement_warn      => vm.retirement[:warn],
          :retirement_last_warn => vm.retirement[:last_warn],
        )
      end
    end

    remove_column :vms, :retirement
  end

  def down
    add_column :vms, :retirement, :text

    say_with_time("Migrating VM Retirement Information") do
      Vm.all.each do |vm|
        retirement             = {}
        retirement[:warn]      = vm.retirement_warn
        retirement[:last_warn] = vm.retirement_last_warn

        vm.update_attributes(:retirement => retirement)
      end
    end

    remove_column :vms, :retirement_warn
    remove_column :vms, :retirement_last_warn
  end
end

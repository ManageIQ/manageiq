class AddDeprecatedToVms < ActiveRecord::Migration[5.0]
  class Vm < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end

  def change
    add_column :vms, :deprecated, :boolean, :default => false
  end
end

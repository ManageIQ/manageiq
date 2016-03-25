class AddMaintenanceToHost < ActiveRecord::Migration[5.0]
  class Host < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end

  def change
    add_column :hosts, :maintenance, :boolean
    add_column :hosts, :maintenance_reason, :string
  end
end

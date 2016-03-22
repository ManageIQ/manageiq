class ChangeRetiresOnToDatetime < ActiveRecord::Migration[5.0]
  def up
    change_column :vms, :retires_on, :datetime
    change_column :services, :retires_on, :datetime
    change_column :orchestration_stacks, :retires_on, :datetime
  end

  def down
    change_column :vms, :retires_on, :date
    change_column :services, :retires_on, :date
    change_column :orchestration_stacks, :retires_on, :date
  end
end

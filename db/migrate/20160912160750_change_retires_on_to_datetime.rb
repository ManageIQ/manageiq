class ChangeRetiresOnToDatetime < ActiveRecord::Migration[5.0]
  def up
    change_column :vms, :retires_on, :datetime
    change_column :services, :retires_on, :datetime
    change_column :orchestration_stacks, :retires_on, :datetime

    change_column :vms, :retirement_last_warn, :datetime
    change_column :services, :retirement_last_warn, :datetime
    change_column :orchestration_stacks, :retirement_last_warn, :datetime
  end

  def down
    change_column :vms, :retires_on, :date
    change_column :services, :retires_on, :date
    change_column :orchestration_stacks, :retires_on, :date

    change_column :vms, :retirement_last_warn, :date
    change_column :services, :retirement_last_warn, :date
    change_column :orchestration_stacks, :retirement_last_warn, :date
  end
end

class AddRetirementToServices < ActiveRecord::Migration
  def change
    add_column :services, :retired,              :boolean
    add_column :services, :retires_on,           :date
    add_column :services, :retirement_warn,      :bigint
    add_column :services, :retirement_last_warn, :datetime
  end
end

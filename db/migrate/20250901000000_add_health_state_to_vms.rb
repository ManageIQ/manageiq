class AddHealthStateToVms < ActiveRecord::Migration[6.1]
  def change
    add_column :vms, :health_state,   :string
    add_column :vms, :health_details, :string
  end
end

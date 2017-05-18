class AddHealthStatePropertyToPhysicalServer < ActiveRecord::Migration[5.0]
  def change
    add_column :physical_servers, :health_state, :string
  end
end

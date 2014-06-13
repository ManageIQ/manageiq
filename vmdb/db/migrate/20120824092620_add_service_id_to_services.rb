class AddServiceIdToServices < ActiveRecord::Migration
  def change
    add_column :services, :service_id, :bigint
  end
end

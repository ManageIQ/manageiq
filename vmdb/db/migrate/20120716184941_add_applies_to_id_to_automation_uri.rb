class AddAppliesToIdToAutomationUri < ActiveRecord::Migration
  def change
    add_column :automation_uris, :applies_to_id, :bigint
  end
end

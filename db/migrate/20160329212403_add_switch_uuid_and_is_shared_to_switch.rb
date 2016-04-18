class AddSwitchUuidAndIsSharedToSwitch < ActiveRecord::Migration[5.0]
  def change
    add_column :switches, :switch_uuid, :string
    add_column :switches, :shared, :boolean
  end
end

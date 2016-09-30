class ChangeArbitrationRulesArbitrationProfileIdToBigInt < ActiveRecord::Migration[5.0]
  def up
    change_column :arbitration_rules, :arbitration_profile_id, :bigint
  end

  def down
    change_column :arbitration_rules, :arbitration_profile_id, :int
  end
end

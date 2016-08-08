class AddTypeToArbitrationProfile < ActiveRecord::Migration[5.0]
  def change
    add_column :arbitration_profiles, :type, :string
    add_column :arbitration_profiles, :profile, :boolean
  end
end

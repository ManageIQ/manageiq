class AddTimestampsToArbitrationProfile < ActiveRecord::Migration[5.0]
  def change
    add_timestamps(:arbitration_profiles)
  end
end

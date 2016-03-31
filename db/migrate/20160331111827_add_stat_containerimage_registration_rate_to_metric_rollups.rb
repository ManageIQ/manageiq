class AddStatContainerimageRegistrationRateToMetricRollups < ActiveRecord::Migration[5.0]
  def change
    add_column :metric_rollups, :stat_container_image_registration_rate, :integer
  end
end

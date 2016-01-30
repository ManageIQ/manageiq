class AddScanColumnsToContainerImages < ActiveRecord::Migration
  def change
    add_column :container_images, :last_sync_on, :datetime
    add_column :container_images, :last_scan_attempt_on, :datetime
  end
end

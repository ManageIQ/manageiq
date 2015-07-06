class RemoveRemoteUiUrlFromMiqRegions < ActiveRecord::Migration
  def self.up
    remove_column :miq_regions, :remote_ui_url
  end

  def self.down
    add_column :miq_regions, :remote_ui_url, :string
  end
end

class AddRemoteUiUrlToMiqRegions < ActiveRecord::Migration
  class MiqRegion < ActiveRecord::Base
    include ReservedMixin
    include MigrationStubHelper # NOTE: Must be included after other mixins
  end

  def self.up
    add_column :miq_regions, :remote_ui_url, :string

    say_with_time("Migrate data from reserved table") do
      MiqRegion.includes(:reserved_rec).each do |r|
        r.reserved_hash_migrate(:remote_ui_url)
      end
    end
  end

  def self.down
    remove_column :miq_regions, :remote_ui_url
  end
end

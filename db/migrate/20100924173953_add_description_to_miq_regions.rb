class AddDescriptionToMiqRegions < ActiveRecord::Migration
  class MiqRegion < ActiveRecord::Base; end

  def self.up
    add_column    :miq_regions, :description, :string

    say_with_time("Update MiqRegion description") do
      MiqRegion.update_all("description = #{ActiveRecordQueryParts.concat(connection.quote("Region "),"miq_regions.region")}")
    end
  end

  def self.down
    remove_column :miq_regions, :description
  end
end

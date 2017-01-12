class MoveRepoDataFromDatabaseToSettings < ActiveRecord::Migration[5.0]
  class MiqRegion < ActiveRecord::Base; end
  class MiqDatabase < ActiveRecord::Base; end
  class SettingsChange < ActiveRecord::Base
    serialize :value
  end

  SETTING_KEY = "/product/update_repo_names".freeze

  def up
    db = MiqDatabase.first
    return unless db && my_region

    say_with_time("Moving repo information from miq_databases to Settings") do
      repos = db.update_repo_name.split
      SettingsChange.create!(settings_hash.merge(:value => repos))
    end
  end

  def down
    return unless my_region
    change = SettingsChange.where(settings_hash).first
    return unless change

    say_with_time("Moving repo information from Settings to miq_databases") do
      db = MiqDatabase.first
      db.update_attributes!(:update_repo_name => change.value.join(" ")) if db
      change.delete
    end
  end

  def my_region
    MiqRegion.find_by_region(ArRegion.anonymous_class_with_ar_region.my_region_number)
  end

  def settings_hash
    {
      :resource_type => "MiqRegion",
      :resource_id   => my_region.id,
      :key           => SETTING_KEY
    }
  end
end

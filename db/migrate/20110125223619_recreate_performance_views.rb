require Rails.root.join('lib/migration_helper')

class RecreatePerformanceViews < ActiveRecord::Migration
  include MigrationHelper::PerformancesViews

  def up
    drop_performances_views
    create_performances_views
  end

  def down
  end
end

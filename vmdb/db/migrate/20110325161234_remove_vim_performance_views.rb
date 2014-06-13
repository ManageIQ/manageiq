require Rails.root.join('lib/migration_helper')

class RemoveVimPerformanceViews < ActiveRecord::Migration
  include MigrationHelper::PerformancesViews

  def up
    drop_performances_views
  end

  def down
    create_performances_views
  end
end

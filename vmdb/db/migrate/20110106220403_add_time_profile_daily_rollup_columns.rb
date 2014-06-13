require Rails.root.join('lib/migration_helper')

class AddTimeProfileDailyRollupColumns < ActiveRecord::Migration
  include MigrationHelper::PerformancesViews

  def up
    add_column :time_profiles,    :rollup_daily_performances, :boolean
    add_column :vim_performances, :time_profile_id,           :bigint

    drop_performances_views
    create_performances_views
  end

  def down
    drop_performances_views

    remove_column :time_profiles,    :rollup_daily_performances
    remove_column :vim_performances, :time_profile_id

    create_performances_views
  end
end

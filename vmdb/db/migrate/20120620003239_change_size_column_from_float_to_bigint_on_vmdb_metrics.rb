class ChangeSizeColumnFromFloatToBigintOnVmdbMetrics < ActiveRecord::Migration
  def up
    change_column :vmdb_metrics, :size, :bigint
  end

  def down
    change_column :vmdb_metrics, :size, :float
  end
end

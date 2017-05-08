class AddStateShowbackBucket < ActiveRecord::Migration[5.0]
  def up
    change_table :showback_buckets do |t|
      t.timestamp   :start_time
      t.timestamp   :end_time
      t.string      :state
      t.monetize    :accumulated_cost
    end
  end

  def down
    remove_monetize :showback_buckets, :accumulated_cost
    remove_column   :showback_buckets, :start_time
    remove_column   :showback_buckets, :end_time
  end
end

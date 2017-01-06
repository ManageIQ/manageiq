class CreateChargeableFields < ActiveRecord::Migration[5.0]
  def change
    create_table :chargeable_fields do |t|
      t.bigint :chargeback_rate_detail_measure_id
      t.string :metric
      t.string :group
      t.string :source
      t.string :description
    end
  end
end

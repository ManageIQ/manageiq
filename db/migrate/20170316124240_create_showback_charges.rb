class CreateShowbackCharges < ActiveRecord::Migration[5.0]
  def change
    create_table :showback_charges, id: :bigserial, force: :cascade do |t|
      t.money :fixed_cost, allow_nil: true
      t.money :variable_cost, allow_nil: true
      t.belongs_to :showback_bucket, type: :bigint, index: true
      t.belongs_to :showback_event, type: :bigint, index: true
      t.timestamps
    end
  end
end

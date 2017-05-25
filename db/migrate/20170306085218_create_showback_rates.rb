class CreateShowbackRates < ActiveRecord::Migration[5.0]
  def change
    create_table :showback_rates, id: :bigserial, force: :cascade do |t|
      t.money :fixed_cost
      t.money :variable_cost
      t.datetime :date
      t.string :concept
      t.timestamps
    end
  end
end

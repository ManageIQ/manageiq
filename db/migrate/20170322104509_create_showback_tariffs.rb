class CreateShowbackTariffs < ActiveRecord::Migration[5.0]
  def change
    create_table :showback_tariffs, id: :bigserial, force: :cascade  do |t|
      t.string :name
      t.string :description

      t.timestamps
    end
  end
end

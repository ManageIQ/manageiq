class CreateShowbackBuckets < ActiveRecord::Migration[5.0]
  def change
    create_table :showback_buckets, id: :bigserial, force: :cascade do |t|
      t.string :name
      t.string :description
      t.references :resource, :polymorphic => true, type: :bigint, index: true
      t.timestamps
    end
  end
end

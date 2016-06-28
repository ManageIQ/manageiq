class FixServiceOrderPlacedAt < ActiveRecord::Migration[5.0]
  def up
    update <<-SQL
      UPDATE "service_orders"
      SET "placed_at" = "updated_at"
      WHERE "state" = 'ordered'
      AND "placed_at" IS NULL
    SQL
  end
end

class CreateHostAggregate < ActiveRecord::Migration[5.0]
  def change
    create_table :host_aggregates do |t|
      t.bigint :ems_id
      t.string :name
      t.string :ems_ref
      t.string :type
      t.text :metadata
    end

    add_index "host_aggregates", ["ems_id"], :name => "index_host_aggregates_on_ems_id"
  end
end

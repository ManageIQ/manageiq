class CreateHostAggregateHost < ActiveRecord::Migration[5.0]
  def change
    create_table :host_aggregate_hosts do |t|
      t.bigint :host_id
      t.bigint :host_aggregate_id
    end

    add_index "host_aggregate_hosts", ["host_id", "host_aggregate_id"], :name => "index_host_aggregate_hosts_on_host_id_and_aggregate_id", :unique => true
  end
end

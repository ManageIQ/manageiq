class CreateServiceConnections < ActiveRecord::Migration[5.0]
  def change
    create_table :service_connections do |t|
      t.bigint :service_bundle_id
      t.bigint :service_template_a_id
      t.bigint :service_template_b_id
      t.text   :properties
    end
    add_index :service_connections, :service_template_a_id
    add_index :service_connections, :service_template_b_id
  end
end

class AddOpenScapResultEntities < ActiveRecord::Migration
  def change
    create_table :openscap_results do |t|
      t.belongs_to :container_image, :type => :bigint
      t.datetime   :created_at
    end
    add_index :openscap_results,      :container_image_id
    create_table :openscap_rule_results do |t|
      t.belongs_to :openscap_result, :type => :bigint
      t.string     :name
      t.string     :result
      t.string     :severity
    end
    add_index :openscap_rule_results, :openscap_result_id
  end
end

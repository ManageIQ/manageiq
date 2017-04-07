class CreateProviderTagsTable < ActiveRecord::Migration[5.0]
  def change
    create_table :provider_tags do |t|
      t.string :key, :null => false, :comment => "The key in a key/value pair."
      t.string :value, :comment => "The value within a key/value pair."
      t.string :resource_id, :null => false, :comment => "Reference to the field used as primary key of the resource."
      t.string :type, :null => false, :comment => "The model name of the resource type."
      t.string :label, :comment => "Optional symbolic label for the key/value pair."
      t.integer :classification_id, :comment => "Optional reference to a Classification."
      t.timestamps
    end
  end
end

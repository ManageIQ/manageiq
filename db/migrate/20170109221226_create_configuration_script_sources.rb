class CreateConfigurationScriptSources < ActiveRecord::Migration[5.0]
  def change
    create_table :configuration_script_sources do |t|
      t.belongs_to  :manager, :type => :bigint
      t.string      :manager_ref
      t.string      :name
      t.string      :description
      t.timestamps
    end
  end
end

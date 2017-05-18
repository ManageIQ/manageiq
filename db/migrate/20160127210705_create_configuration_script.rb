class CreateConfigurationScript < ActiveRecord::Migration[4.2]
  def change
    create_table :configuration_scripts do |t|
      t.belongs_to :configuration_manager, :type => :bigint

      t.string :manager_ref
      t.string :name
      t.string :description
      t.text   :variables

      t.timestamps :null => false
    end
  end
end

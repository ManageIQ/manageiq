class CreateResourceActions < ActiveRecord::Migration
  def change
    create_table :resource_actions do |t|
      t.string      :action
      t.belongs_to  :dialog
      t.belongs_to  :resource,    :polymorphic => true
      t.timestamps
    end
  end
end

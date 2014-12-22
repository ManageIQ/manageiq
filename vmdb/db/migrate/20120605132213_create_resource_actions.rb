class CreateResourceActions < ActiveRecord::Migration
  def change
    create_table :resource_actions do |t|
      t.string      :action
      t.belongs_to  :dialog,                         :type => :bigint
      t.belongs_to  :resource, :polymorphic => true, :type => :bigint
      t.timestamps
    end
  end
end

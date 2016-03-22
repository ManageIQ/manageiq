class CreateJoinTableHostSwitch < ActiveRecord::Migration[5.0]
  def change
    create_join_table :hosts, :switches do |t|
      t.index [:host_id, :switch_id]
      t.index [:switch_id, :host_id]
    end
  end
end

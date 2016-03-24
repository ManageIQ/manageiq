class CreateJoinTableHostSwitch < ActiveRecord::Migration[5.0]
  def change
    create_table :hosts_switches do |t|
      t.bigint  :host_id
      t.bigint  :switch_id
    end
  end
end

class RemoveBlackBoxFromVms < ActiveRecord::Migration
  def up
    change_table "vms" do |t|
      t.remove "blackbox_exists"
      t.remove "blackbox_validated"
    end
  end

  def down
    change_table "vms" do |t|
      t.boolean "blackbox_exists"
      t.boolean "blackbox_validated"
    end
  end
end

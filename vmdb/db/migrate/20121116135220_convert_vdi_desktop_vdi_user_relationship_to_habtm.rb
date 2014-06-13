class ConvertVdiDesktopVdiUserRelationshipToHabtm < ActiveRecord::Migration
  class VdiDesktop < ActiveRecord::Base; end
  class VdiDesktopsVdiUsers < ActiveRecord::Base
    self.primary_key = nil
  end

  def up
    create_table :vdi_desktops_vdi_users, :id => false do |t|
      t.bigint   :vdi_desktop_id
      t.bigint   :vdi_user_id
    end

    say_with_time("Migrating VDI Users") do
      VdiDesktop.where("vdi_user_id IS NOT NULL").each do |vdi_desktop|
        VdiDesktopsVdiUsers.create!(:vdi_desktop_id => vdi_desktop.id, :vdi_user_id => vdi_desktop.vdi_user_id)
      end
    end

    remove_column :vdi_desktops, :vdi_user_id
  end

  def down
    add_column :vdi_desktops, :vdi_user_id, :bigint

    say_with_time("Migrating VDI Users") do
      VdiDesktopsVdiUsers.group(:vdi_desktop_id).select([:vdi_desktop_id, "MIN(vdi_user_id) AS vdi_user_id"]).each do |join|
        VdiDesktop.where(:id => join.vdi_desktop_id).update_all(:vdi_user_id => join.vdi_user_id)
      end
    end

    drop_table :vdi_desktops_vdi_users
  end

end

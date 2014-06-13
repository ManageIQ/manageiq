require "spec_helper"
require Rails.root.join("db/migrate/20121116135220_convert_vdi_desktop_vdi_user_relationship_to_habtm.rb")

describe ConvertVdiDesktopVdiUserRelationshipToHabtm do
  migration_context :up do
    let(:vdi_desktop_stub) { migration_stub(:VdiDesktop) }
    let(:join_table_stub)  { migration_stub(:VdiDesktopsVdiUsers) }

    it "migrates VDI Users" do
      vdi_desktop = vdi_desktop_stub.create!(:vdi_user_id => 123)

      migrate

      recs = join_table_stub.where(:vdi_desktop_id => vdi_desktop.id).all
      recs.size.should == 1
      recs.first.vdi_user_id.should == 123
    end

    it "ignores vdi_desktops with no users" do
      vdi_desktop = vdi_desktop_stub.create!(:vdi_user_id => nil)

      migrate

      join_table_stub.where(:vdi_desktop_id => vdi_desktop.id).count.should == 0
    end
  end

  migration_context :down do
    let(:vdi_desktop_stub) { migration_stub(:VdiDesktop) }
    let(:join_table_stub)  { migration_stub(:VdiDesktopsVdiUsers) }

    it "migrates VDI Users" do
      vdi_desktop  = vdi_desktop_stub.create!

      join_table_stub.create!(:vdi_desktop_id => vdi_desktop.id, :vdi_user_id => 123)
      join_table_stub.create!(:vdi_desktop_id => vdi_desktop.id, :vdi_user_id => 124)

      migrate

      vdi_desktop.reload.vdi_user_id.should == 123
    end

    it "ignores vdi_desktops with no users" do
      vdi_desktop = vdi_desktop_stub.create!

      migrate

      vdi_desktop.reload.vdi_user_id.should be_nil
    end
  end
end

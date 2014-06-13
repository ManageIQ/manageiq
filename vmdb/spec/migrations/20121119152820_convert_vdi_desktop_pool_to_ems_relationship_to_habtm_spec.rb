require "spec_helper"
require Rails.root.join("db/migrate/20121119152820_convert_vdi_desktop_pool_to_ems_relationship_to_habtm.rb")

describe ConvertVdiDesktopPoolToEmsRelationshipToHabtm do
  migration_context :up do
    let(:vdi_desktop_pool_stub) { migration_stub(:VdiDesktopPool) }
    let(:join_table_stub)       { migration_stub(:ExtManagementSystemsVdiDesktopPools) }

    it "migrates VDI Desktop Pools" do
      vdi_desktop_pool = vdi_desktop_pool_stub.create!(:ems_id => 123)

      migrate

      recs = join_table_stub.where(:vdi_desktop_pool_id => vdi_desktop_pool.id).all
      recs.size.should == 1
      recs.first.ems_id.should == 123
    end

    it "ignores vdi_desktop_pools with no EMS" do
      vdi_desktop_pool = vdi_desktop_pool_stub.create!(:ems_id => nil)

      migrate

      join_table_stub.where(:vdi_desktop_pool_id => vdi_desktop_pool.id).count.should == 0
    end
  end

  migration_context :down do
    let(:vdi_desktop_pool_stub) { migration_stub(:VdiDesktopPool) }
    let(:join_table_stub)       { migration_stub(:ExtManagementSystemsVdiDesktopPools) }

    it "migrates VDI Desktop Pools" do
      vdi_desktop_pool  = vdi_desktop_pool_stub.create!

      join_table_stub.create!(:vdi_desktop_pool_id => vdi_desktop_pool.id, :ems_id => 123)
      join_table_stub.create!(:vdi_desktop_pool_id => vdi_desktop_pool.id, :ems_id => 234)

      migrate

      vdi_desktop_pool.reload.ems_id.should == 123
    end

    it "ignores vdi_desktop_pools with no EMS" do
      vdi_desktop_pool = vdi_desktop_pool_stub.create!

      migrate

      vdi_desktop_pool.reload.ems_id.should be_nil
    end
  end
end

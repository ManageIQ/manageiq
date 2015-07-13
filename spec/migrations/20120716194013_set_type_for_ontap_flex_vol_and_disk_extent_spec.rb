require "spec_helper"
require Rails.root.join("db/migrate/20120716194013_set_type_for_ontap_flex_vol_and_disk_extent.rb")

describe SetTypeForOntapFlexVolAndDiskExtent do
  let(:miq_cim_instance_stub) { migration_stub(:MiqCimInstance) }
  migration_context :up do
    it "migrates ONTAP_FlexVolExtent to OntapFlexVolExtent" do
      mci = miq_cim_instance_stub.create!(:class_name => 'ONTAP_FlexVolExtent')
      migrate
      mci.reload
      mci.type.should == 'OntapFlexVolExtent'
      mci.class_name.should == 'ONTAP_FlexVolExtent' # should not change
    end

    it "migrates ONTAP_DiskExtent to OntapDiskExtent" do
      mci = miq_cim_instance_stub.create!(:class_name => 'ONTAP_DiskExtent')
      migrate
      mci.reload
      mci.type.should == 'OntapDiskExtent'
      mci.class_name.should == 'ONTAP_DiskExtent'
    end
  end

  migration_context :down do
    it "drops type for ONTAP_DiskExtent" do
      mci = miq_cim_instance_stub.create!(
        :type => 'OntapFlexVolExtent',
        :class_name => 'ONTAP_FlexVolExtent'
      )
      migrate
      mci.reload
      mci.type.should be_nil
      mci.class_name.should == 'ONTAP_FlexVolExtent'
    end
    it "drops type for ONTAP_DiskExtent" do
      mci = miq_cim_instance_stub.create!(
        :type => 'OntapDiskExtent',
        :class_name => 'ONTAP_DiskExtent'
      )
      migrate
      mci.reload
      mci.type.should be_nil
      mci.class_name.should == 'ONTAP_DiskExtent'
    end
  end
end

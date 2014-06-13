require "spec_helper"

describe EmsRefresh do
  context ".queue_refresh" do
    before(:each) do
      guid, server, zone = EvmSpecHelper.seed_for_miq_queue
      @ems = FactoryGirl.create(:ems_vmware, :zone => zone)
    end

    it "with Ems" do
      target = @ems
      queue_refresh_and_assert_queue_item(target, [target])
    end

    it "with Host" do
      target = FactoryGirl.create(:host_vmware, :ext_management_system => @ems)
      queue_refresh_and_assert_queue_item(target, [target])
    end

    it "with Host acting as an Ems" do
      target = FactoryGirl.create(:host_microsoft)
      queue_refresh_and_assert_queue_item(target, [target])
    end

    it "with Vm" do
      target = FactoryGirl.create(:vm_vmware, :ext_management_system => @ems)
      queue_refresh_and_assert_queue_item(target, [target])
    end

    it "with Storage" do
      Storage.any_instance.stub(:ext_management_systems => [@ems])
      target = FactoryGirl.create(:storage_vmware)
      queue_refresh_and_assert_queue_item(target, [target])
    end

    it "with Vm and an item already on the queue" do
      target = @ems
      queue_refresh_and_assert_queue_item(target, [target])
      target2 = FactoryGirl.create(:vm_vmware, :ext_management_system => @ems)
      queue_refresh_and_assert_queue_item(target2, [target, target2])
    end

    def queue_refresh_and_assert_queue_item(target, expected_targets)
      described_class.queue_refresh(target)

      q_all = MiqQueue.all
      q_all.length.should == 1
      q_all[0].args.should        == [expected_targets.collect {|t| [t.class.name, t.id]}]
      q_all[0].class_name.should  == described_class.name
      q_all[0].method_name.should == 'refresh'
      q_all[0].role.should        == "ems_inventory"
    end
  end

  context ".get_ar_objects" do
    it "instance"
    it "array of instances"
    it "class/id pair"
    it "class_name/id pair"

    it "array of class/ids pairs" do
      ems1 = FactoryGirl.create(:ems_vmware,     :name => "ems_vmware1")
      ems2 = FactoryGirl.create(:ems_redhat, :name => "ems_redhat1")
      pairs = [
        [ems1.class, ems1.id],
        [ems2.class, ems2.id]
      ]

      described_class.get_ar_objects(pairs).should have_same_elements([ems1, ems2])
    end

    it "array of class_name/id pairs"

  end
end

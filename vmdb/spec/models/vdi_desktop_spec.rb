require "spec_helper"

describe VdiDesktop do
  context "with a small envs" do
    before(:each) do
      @zone1 = FactoryGirl.create(:small_environment)
      @host1 = @zone1.ext_management_systems.first.hosts.first
      @zone1.reload
      @vm = @zone1.ext_management_systems.first.vms.first
      @task = FactoryGirl.create(:miq_task)
    end

    it "VmVdi#mark_as_vdi" do
      @vm.vdi.should be_false
      VdiDesktop.count.should == 0
      VmVdi.mark_as_vdi([@vm.id], @task.id)
      @vm.reload
      @vm.vdi.should be_true
      @task.task_results[:success_msgs].count.should == 1
      VdiDesktop.count.should == 1
    end

    it "VmVdi#mark_as_vdi Template VM" do
      @vm.update_attribute(:template, true)
      @vm.template?.should be_true
      VmVdi.mark_as_vdi([@vm.id], @task.id)
      @task.task_results[:error_msgs].count.should == 1
      @vm.vdi.should be_false
      VdiDesktop.count.should == 0
    end

    it "VmVdi#mark_as_vdi Archived VM" do
      @vm.update_attributes(:ems_id => nil, :storage_id => nil)
      @vm.archived?.should be_true
      VmVdi.mark_as_vdi([@vm.id], @task.id)
      @task.task_results[:error_msgs].count.should == 1
      @vm.vdi.should be_false
      VdiDesktop.count.should == 0
    end

    it "VmVdi#mark_as_vdi Orphaned VM" do
      @vm.update_attribute(:ems_id, nil)
      VmVdi.mark_as_vdi([@vm.id], @task.id)
      @vm.vdi.should be_false
      @task.task_results[:error_msgs].count.should == 1
      VdiDesktop.count.should == 0
    end

    context "with a VDI Desktop" do
      before(:each) do
        VmVdi.mark_as_vdi([@vm.id], @task.id)
        @vm.reload
        @desktop = VdiDesktop.first
      end

      it "VmVdi#mark_as_non_vdi not in a Desktop Pool" do
        VmVdi.mark_as_non_vdi([@desktop.id], @task.id)
        @vm.reload
        @task.task_results[:success_msgs].count.should == 1
        @vm.vdi.should be_false
        VdiDesktop.count.should == 0
      end

      it "VmVdi#mark_as_non_vdi brokered Desktop Pool" do
        farm = FactoryGirl.create(:vdi_farm_citrix)
        pool = FactoryGirl.create(:vdi_desktop_pool, :name => 'MiqCitrix1', :vendor => 'citrix', :enabled => true)
        farm.vdi_desktop_pools << pool
        pool.vdi_desktops << @desktop

        VmVdi.mark_as_non_vdi([@desktop.id], @task.id)
        @vm.reload
        @task.task_results[:error_msgs].count.should == 1
        @vm.vdi.should be_true
        VdiDesktop.count.should == 1
      end

    end

    context "with VDI Desktop and virtual columns" do
      before(:each) do
        @desktop = FactoryGirl.create(:vdi_desktop, :vm_or_template => @vm)
      end

      it "ipaddresses and hostnames should be nil" do
        @desktop.ipaddresses.should be_empty
        @desktop.hostnames.should   be_empty
      end

      it "ipaddresses and hostnames should have values" do
        @vm.stub(:ipaddresses => ['192.168.1.1'], :hostnames => ['Host_1'])

        @desktop.ipaddresses.should be_a_kind_of(Array)
        @desktop.hostnames.should   be_a_kind_of(Array)

        @desktop.ipaddresses.should == ['192.168.1.1']
        @desktop.hostnames.should   == ['Host_1']
      end
    end

  end
end

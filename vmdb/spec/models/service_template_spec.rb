require "spec_helper"

describe ServiceTemplate do

  context "#type_display" do
    before(:each) do
      @st1 = FactoryGirl.create(:service_template, :name => 'Service Template 1')
    end

    it "with service_type of unknown" do
      @st1.type_display.should == 'Unknown'
    end

    it "with service_type of atomic" do
      @st1.update_attributes(:service_type => 'atomic')
      @st1.type_display.should == 'Item'
    end

    it "with service_type of composite" do
      @st1.update_attributes(:service_type => 'composite')
      @st1.type_display.should == 'Bundle'
    end
  end

  context "#atomic?" do
    before(:each) do
      @st1 = FactoryGirl.create(:service_template)
    end

    it "with service_type of unknown" do
      @st1.atomic?.should be_false
    end

    it "with service_type of atomic" do
      @st1.update_attributes(:service_type => 'atomic')
      @st1.atomic?.should be_true
    end
  end

  context "#composite?" do
    before(:each) do
      @st1 = FactoryGirl.create(:service_template)
    end

    it "with service_type of unknown" do
      @st1.composite?.should be_false
    end

    it "with service_type of composite" do
      @st1.update_attributes(:service_type => 'composite')
      @st1.composite?.should be_true
    end
  end


  context "with multiple services" do
    before(:each) do
      @svc_a = FactoryGirl.create(:service_template, :name => 'Svc A')
      @svc_b = FactoryGirl.create(:service_template, :name => 'Svc B')
      @svc_c = FactoryGirl.create(:service_template, :name => 'Svc C')
      @svc_d = FactoryGirl.create(:service_template, :name => 'Svc D')
      @svc_e = FactoryGirl.create(:service_template, :name => 'Svc E')
    end

    it "should return level 1 sub-services" do
      add_and_save_service(@svc_a, @svc_b)
      add_and_save_service(@svc_b, @svc_c)
      add_and_save_service(@svc_a, @svc_c)
      add_and_save_service(@svc_c, @svc_d)

      sub_svc = @svc_a.sub_services
      sub_svc.should_not include(@svc_a)
      sub_svc.should have(2).things
      sub_svc.should include(@svc_b)
      sub_svc.should include(@svc_c)
      sub_svc.should_not include(@svc_d)
    end

    it "should return all sub-services" do
      add_and_save_service(@svc_a, @svc_b)
      add_and_save_service(@svc_b, @svc_c)
      add_and_save_service(@svc_a, @svc_c)
      add_and_save_service(@svc_c, @svc_d)

      sub_svc = @svc_a.sub_services({:recursive => true})
      sub_svc.should have(5).things
      sub_svc.should_not include(@svc_a)
      sub_svc.should include(@svc_b)
      sub_svc.should include(@svc_c)
      sub_svc.should include(@svc_d)

      sub_svc.uniq!
      sub_svc.should have(3).things
      sub_svc.should_not include(@svc_a)
      sub_svc.should include(@svc_b)
      sub_svc.should include(@svc_c)
      sub_svc.should include(@svc_d)
    end

    it "should return all parent services for a service" do
      add_and_save_service(@svc_a, @svc_b)
      add_and_save_service(@svc_a, @svc_c)
      add_and_save_service(@svc_a, @svc_d)
      add_and_save_service(@svc_b, @svc_c)

      @svc_a.parent_services.should be_empty

      parents = @svc_b.parent_services
      parents.should have(1).thing
      parents.first.name.should == @svc_a.name

      parents = @svc_c.parent_services
      parents.should have(2).things
      parent_names = parents.collect(&:name)
      parent_names.should include(@svc_a.name)
      parent_names.should include(@svc_b.name)
    end

    it "should not allow service templates to be connected to itself" do
      expect { add_and_save_service(@svc_a, @svc_a) }.to raise_error
    end

    it "should not allow service templates to be connected in a circular reference" do
      lambda { add_and_save_service(@svc_a, @svc_b) }.should_not raise_error
      lambda { add_and_save_service(@svc_b, @svc_c) }.should_not raise_error
      lambda { add_and_save_service(@svc_a, @svc_c) }.should_not raise_error
      lambda { add_and_save_service(@svc_c, @svc_d) }.should_not raise_error
      lambda { add_and_save_service(@svc_a, @svc_e) }.should_not raise_error

      lambda { add_and_save_service(@svc_c, @svc_a) }.should raise_error
      lambda { add_and_save_service(@svc_d, @svc_a) }.should raise_error
      lambda { add_and_save_service(@svc_c, @svc_b) }.should raise_error

      # Print tree-view of services
      # puts "\n#{svc_a.name}"
      # print_svc(svc_a, "  ")
    end

    it "should not allow deeply nested service templates to be connected in a circular reference" do
      lambda { add_and_save_service(@svc_a, @svc_b) }.should_not raise_error
      lambda { add_and_save_service(@svc_b, @svc_c) }.should_not raise_error

      lambda { add_and_save_service(@svc_d, @svc_e) }.should_not raise_error
      lambda { add_and_save_service(@svc_e, @svc_a) }.should_not raise_error

      lambda { add_and_save_service(@svc_c, @svc_d) }.should raise_error
    end

    it "should not allow service template to connect to self" do
      expect { @svc_a << @svc_a }.to raise_error
    end

    it "should allow service template to connect to a service with the same id" do
      svc = FactoryGirl.create(:service)
      svc.id = @svc_a.id
      expect { svc << @svc_a }.to_not raise_error
    end

    it "should not delete a service that has a parent service" do
      add_and_save_service(@svc_a, @svc_b)
      add_and_save_service(@svc_b, @svc_c)

      lambda { @svc_b.destroy }.should raise_error
      lambda { @svc_c.destroy }.should raise_error

      lambda { @svc_a.destroy }.should_not raise_error
      lambda { @svc_b.destroy }.should_not raise_error
      lambda { @svc_c.destroy }.should_not raise_error
    end

  end

  context "with a small env" do
    before(:each) do
      @zone1 = FactoryGirl.create(:small_environment)
      MiqServer.stub(:my_server).and_return(@zone1.miq_servers.first)
      @st1 = FactoryGirl.create(:service_template, :name => 'Service Template 1')
    end

    it "should create a valid service template" do
      @st1.guid.should_not be_empty
      @st1.service_resources.should have(0).things
    end

    it "should not set the owner for the service template" do
      @user         = nil
      @test_service = FactoryGirl.create(:service, :name => 'test service')
      @test_service.evm_owner.should be_nil
      @st1.set_ownership(@test_service, @user)
      @test_service.evm_owner.should be_nil
    end

    it "should set the owner and group for the service template" do
      @group        = FactoryGirl.create(:miq_group, :description => 'Test Group')
      @user         = FactoryGirl.create(:user,
                                         :name       => 'Test Service Owner',
                                         :userid     => 'test_user',
                                         :miq_groups => [@group])
      @test_service = FactoryGirl.create(:service, :name => 'test service')
      @test_service.evm_owner.should be_nil
      @st1.set_ownership(@test_service, @user)
      @test_service.reload
      @test_service.evm_owner.name.should == 'Test Service Owner'
      @test_service.evm_owner.current_group.should_not be_nil
      @test_service.evm_owner.current_group.description.should == 'Test Group'
    end

    it "should create an empty service template without a type" do
      @st1.service_type.should == 'unknown'
      @st1.composite?.should be_false
      @st1.atomic?.should be_false
    end

    it "should create a composite service template" do
      st2 = FactoryGirl.create(:service_template, :name => 'Service Template 2')
      @st1.add_resource(st2)
      @st1.service_resources.should have(1).thing
      @st1.composite?.should be_true
      @st1.atomic?.should be_false
    end

    it "should create an atomic service template" do
      vm = Vm.first
      @st1.add_resource(vm)
      @st1.service_resources.should have(1).thing
      @st1.atomic?.should be_true
      @st1.composite?.should be_false
    end

    context "with a VM Provision Request Template" do
      before(:each) do
        User.any_instance.stub(:role).and_return("admin")
        @user        = FactoryGirl.create(:user, :name => 'Fred Flintstone',  :userid => 'fred')
        @approver    = FactoryGirl.create(:user, :name => 'Wilma Flintstone', :userid => 'approver')
        UiTaskSet.stub(:find_by_name).and_return(@approver)

        vm_template = Vm.first
        ptr = FactoryGirl.create(:miq_provision_request_template, :userid => @user.userid, :src_vm_id => vm_template.id)
        @st1.add_resource(ptr)
      end

      it "should allow VM Provision Request Template as a resource" do
        @st1.service_resources.should have(1).thing
        @st1.atomic?.should be_true
        @st1.composite?.should be_false
      end

      it "should delete the VM Provision Request Template when the service template is deleted" do
        ServiceTemplate.count.should == 1
        MiqProvisionRequestTemplate.count.should == 1
        @st1.destroy
        ServiceTemplate.count.should == 0
        MiqProvisionRequestTemplate.count.should == 0
      end
    end
  end
end

def add_and_save_service(p,c)
  p.add_resource(c)
  p.service_resources.each {|sr| sr.save}
end

def print_svc(svc, indent="")
  return if indent.length > 10
  svc.service_resources.each do |s|
    puts indent + s.resource.name
    print_svc(s.resource, indent + "  ")
  end
end

require "spec_helper"

describe CustomButton do
  context "with no buttons" do
    before(:each) do
      @guid = MiqUUID.new_guid
      MiqServer.stub(:my_guid).and_return(@guid)
      @zone       = FactoryGirl.create(:zone)
      @miq_server = FactoryGirl.create(:miq_server_master, :zone => @zone, :guid => @guid)
      MiqServer.my_server(true)

      User.any_instance.stub(:role).and_return("admin")
      @user = FactoryGirl.create(:user, :name => 'Fred Flintstone',  :userid => 'fred')
    end

    it "should validate there are no buttons" do
      described_class.count.should == 0
    end

    context "when I create a button via save_as_button class method" do
      before(:each) do
        @button_name   = "Power ON"
        @button_text   = "Power ON during Business Hours ONLY"
        @button_number = 3
        @button_class  = "Vm"
        @ae_name       = 'Automation'
        @ae_attributes = { 'phrase' => 'Hello World'}
        @ae_uri        = MiqAeEngine.create_automation_object(@ae_name, @ae_attributes)
        @userid        = "guest"
        @target_attr_name = "foo"
        @button = described_class.save_as_button(
                    :name             => @button_name,
                    :description      => @button_text,
                    :applies_to_class => @button_class,
                    :uri              => @ae_uri,
                    :userid           => @userid,
                    :target_attr_name => @target_attr_name
                  )

      end

      it "creates the proper button" do
        described_class.count.should == 1
        @button.uri_path.should   == '/System/Process/Automation'
        @button.options[:target_attr_name].should == @target_attr_name
        @button.uri_object_name.should == @ae_name
        @ae_attributes.each { |key, value| @button.uri_attributes[key].should == value.to_s }

        # These attributes are not longer stored with the button
        @button.uri_attributes['User::user'].should be_nil
        @button.uri_attributes['MiqServer::miq_server'].should be_nil
      end

      context "when invoking for a particular VM" do
        before(:each) do
          @vm    = FactoryGirl.create(:vm_vmware)
          @user2 = FactoryGirl.create(:user, :name => 'Wilma Flintstone',  :userid => 'wilma')
        end

        it "calls automate without saved User and MiqServer" do
          User.with_userid(@user2.userid) { @button.invoke(@vm) }

          MiqQueue.count.should == 1
          q = MiqQueue.first
          q.class_name.should  == "MiqAeEngine"
          q.method_name.should == "deliver"
          q.role.should        == "automate"
          q.zone.should eq("default")
          q.priority.should    == MiqQueue::HIGH_PRIORITY
          a = q.args
          a.should be_kind_of(Array)
          h = a.first
          h.should be_kind_of(Hash)
          h[:user_id].should       == @user2.id
          h[:object_type].should   == @vm.class.base_class.name
          h[:object_id].should     == @vm.id
          h[:attrs].should         == @ae_attributes
          h[:instance_name].should == @ae_name
        end
      end
    end
  end

  it ".buttons_for" do
    vm         = FactoryGirl.create(:vm_vmware)
    vm_other   = FactoryGirl.create(:vm_vmware)
    button1all = FactoryGirl.create(:custom_button,
                              :applies_to  => vm.class,
                              :name        => "foo",
                              :description => "foo foo")

    button1vm  = FactoryGirl.create(:custom_button,
                              :applies_to  => vm,
                              :name        => "bar",
                              :description => "bar bar")

    button2vm  = FactoryGirl.create(:custom_button,
                              :applies_to  => vm,
                              :name        => "foo",
                              :description => "foo foo")

    described_class.buttons_for(Host).all.should == []
    described_class.buttons_for(Vm).all.should   == [button1all]
    described_class.buttons_for(vm).all.should  match_array([button1vm, button2vm])
    described_class.buttons_for(vm_other).all.should == []
  end

  it "#save" do
    ra     = FactoryGirl.create(:resource_action, :ae_namespace => 'SYSTEM', :ae_class => 'PROCESS', :ae_message => 'create')
    button = FactoryGirl.create(:custom_button, :name => "My test button", :applies_to => Vm, :resource_action => ra)
    button.save

    ra.ae_message = "new message"
    button.save

    button.reload.resource_action.ae_message.should == 'new message'
  end

  context "validates uniqueness" do
    before(:each) do
      @vm = FactoryGirl.create(:vm_vmware)
      @default_name = @default_description = "boom"
    end

    it "applies_to_class" do
      button_for_all_vms = FactoryGirl.create(:custom_button,
                             :applies_to_class => 'Vm',
                             :name             => @default_name,
                             :description      => @default_description)
      button_for_all_vms.should be_valid

      new_host_button = described_class.new(
                             :applies_to_class => 'Host',
                             :name             => @default_name,
                             :description      => @default_description)
      new_host_button.should be_valid

      dup_vm_button = described_class.new(
                             :applies_to_class => 'Vm',
                             :name             => @default_name,
                             :description      => @default_description)
      dup_vm_button.should_not be_valid

      dup_vm_name_button = described_class.new(
                             :applies_to_class => 'Vm',
                             :name             => @default_name,
                             :description      => "hello world")
      dup_vm_name_button.should_not be_valid

      dup_vm_desc_button = described_class.new(
                             :applies_to_class => 'Vm',
                             :name             => "hello",
                             :description      => @default_description)
      dup_vm_desc_button.should_not be_valid

      new_vm_button = described_class.new(
                             :applies_to_class => 'Vm',
                             :name             => "hello",
                             :description      => "hello world")
      new_vm_button.should be_valid
    end

    it "applies_to_instance" do
      vm_other = FactoryGirl.create(:vm_vmware)

      button_for_single_vm = FactoryGirl.create(:custom_button,
                                # :applies_to_class => "Vm",
                                # :applies_to_id    => @vm.id,
                                :applies_to  => @vm,
                                :name        => @default_name,
                                :description => @default_description)
      button_for_single_vm.should be_valid

      # For same VM
      dup_vm_button = described_class.new(
                                :applies_to  => @vm,
                                :name        => @default_name,
                                :description => @default_description)
      dup_vm_button.should_not be_valid

      dup_vm_name_button = described_class.new(
                                :applies_to  => @vm,
                                :name        => @default_name,
                                :description => "hello world")
      dup_vm_name_button.should_not be_valid

      dup_vm_desc_button = described_class.new(
                                :applies_to  => @vm,
                                :name        => "hello",
                                :description => @default_description)
      dup_vm_desc_button.should_not be_valid

      new_vm_button = described_class.new(
                                :applies_to  => @vm,
                                :name        => "hello",
                                :description => "hello world")
      new_vm_button.should be_valid

      # For other VM
      dup_vm_button = described_class.new(
                                :applies_to  => vm_other,
                                :name        => @default_name,
                                :description => @default_description)
      dup_vm_button.should be_valid

      dup_vm_name_button = described_class.new(
                                :applies_to  => vm_other,
                                :name        => @default_name,
                                :description => "hello world")
      dup_vm_name_button.should be_valid

      dup_vm_desc_button = described_class.new(
                                :applies_to  => vm_other,
                                :name        => "hello",
                                :description => @default_description)
      dup_vm_desc_button.should be_valid

      new_vm_button = described_class.new(
                                :applies_to  => vm_other,
                                :name        => "hello",
                                :description => "hello world")
      new_vm_button.should be_valid
    end
  end
end

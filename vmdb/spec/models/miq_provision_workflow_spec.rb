require "spec_helper"

silence_warnings { MiqProvisionWorkflow.const_set("DIALOGS_VIA_AUTOMATE", false) }

describe MiqProvisionWorkflow do
  context "seeded" do
    context "After setup," do
      before(:each) do
        @guid = MiqUUID.new_guid
        MiqServer.stub(:my_guid => @guid)

        @zone = FactoryGirl.create(:zone)
        MiqServer.stub(:my_zone => @zone)

        @server = FactoryGirl.create(:miq_server, :zone => @zone, :guid => @guid, :status => "started")
        MiqServer.stub(:my_server => @server)

        super_role   = FactoryGirl.create(:ui_task_set, :name => 'super_administrator', :description => 'Super Administrator')
        @admin       = FactoryGirl.create(:user, :name => 'admin',            :userid => 'admin',    :ui_task_set_id => super_role.id)
        @user        = FactoryGirl.create(:user, :name => 'Fred Flintstone',  :userid => 'fred',     :ui_task_set_id => super_role.id)
        @approver    = FactoryGirl.create(:user, :name => 'Wilma Flintstone', :userid => 'approver', :ui_task_set_id => super_role.id)
        UiTaskSet.stub(:find_by_name).and_return(@approver)

        FactoryGirl.create(:miq_dialog_provision)
      end

      context "Without a Valid Template," do
        it "should not create an MiqRequest when calling from_ws" do
          lambda { MiqProvisionVmwareWorkflow.from_ws("1.0", "admin", "template", "target", false, "cc|001|environment|test", "")}.should raise_error(RuntimeError)
        end
      end

      context "With a Valid Template," do
        before(:each) do
          @ems         = FactoryGirl.create(:ems_vmware,  :name => "Test EMS",  :zone => @zone)
          @host        = FactoryGirl.create(:host, :name => "test_host", :hostname => "test_host", :state => 'on', :ext_management_system => @ems)
          @vm_template = FactoryGirl.create(:template_vmware, :name => "template", :ext_management_system => @ems, :host => @host)
          @hardware    = FactoryGirl.create(:hardware, :vm_or_template => @vm_template, :guest_os => "winxppro", :memory_cpu => 512, :numvcpus => 2)
          @switch      = FactoryGirl.create(:switch, :name => 'vSwitch0', :ports => 32, :host => @host)
          @lan         = FactoryGirl.create(:lan, :name => "VM Network", :switch => @switch)
          @ethernet    = FactoryGirl.create(:guest_device, :hardware => @hardware, :lan => @lan, :device_type => 'ethernet', :controller_type => 'ethernet', :address => '00:50:56:ba:10:6b', :present => false, :start_connected => true)
        end

        it "should create an MiqRequest when calling from_ws" do
          request = MiqProvisionVmwareWorkflow.from_ws("1.0", "admin", "template", "target", false, "cc|001|environment|test", "")
          request.should be_a_kind_of(MiqRequest)
        end

        it "should encrypt fields" do
          password_input = "secret"
          request = MiqProvisionVmwareWorkflow.from_ws("1.1", "admin", "name=template", "vm_name=spec_test|root_password=#{password_input}",
                                                       "owner_email=admin|owner_first_name=test|owner_last_name=test", nil, nil, nil, nil)

          MiqPassword.encrypted?(request.options[:root_password]).should be_true
          MiqPassword.decrypt(request.options[:root_password]).should    == password_input
        end
      end

      context "#show_customize_fields" do
        it "should show PXE fields when customization supported" do
          fields = {'key' => 'value'}
          wf = MiqProvisionVirtWorkflow.new({}, @admin.userid)
          wf.should_receive(:supports_customization_template?).and_return(true)
          wf.should_receive(:show_customize_fields_pxe).with(fields)
          wf.show_customize_fields(fields, 'linux')
        end
      end
    end
  end

  context ".encrypted_options_fields" do
    MiqProvisionWorkflow.descendants.each do |sub_klass|
      it("with class #{sub_klass}") { sub_klass.encrypted_options_fields.should include(:root_password) }
    end
  end
end

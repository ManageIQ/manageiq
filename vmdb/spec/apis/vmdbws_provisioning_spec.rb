require "spec_helper"

describe VmdbwsController, :apis => true do

  before(:each) do
    MiqRegion.seed
    MiqDialog.seed

    @guid = MiqUUID.new_guid
    MiqServer.stub(:my_guid).and_return(@guid)

    @zone       = FactoryGirl.create(:zone)
    @miq_server = FactoryGirl.create(:miq_server, :guid => @guid, :zone => @zone)
    MiqServer.stub(:my_server).and_return(@miq_server)

    super_role   = FactoryGirl.create(:ui_task_set, :name => 'super_administrator', :description => 'Super Administrator')
    @admin       = FactoryGirl.create(:user, :name => 'admin',            :userid => 'admin',    :ui_task_set_id => super_role.id)
    @user        = FactoryGirl.create(:user, :name => 'Fred Flintstone',  :userid => 'fred',     :ui_task_set_id => super_role.id)
    @approver    = FactoryGirl.create(:user, :name => 'Wilma Flintstone', :userid => 'approver', :ui_task_set_id => super_role.id)
    UiTaskSet.stub(:find_by_name).and_return(@approver)

    ::UiConstants
    @controller = VmdbwsController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    @controller.stub(:authenticate).and_return(true)

    @controller.instance_variable_set(:@username, "admin")
  end

  it 'should send a web-service ping to the server' do
    invoke(:EVM_ping, "valid").should be_true
  end

  context "With a Valid Template," do
    before(:each) do
      @ems         = FactoryGirl.create(:ems_vmware_with_authentication,  :name => "Test EMS",  :zone => @zone)

      # Don't attempt to connect to the ems as a side-effect of doing provision type WS calls
      @ems.class.any_instance.stub(:connect).and_raise("some error")

      @host        = FactoryGirl.create(:host, :name => "test_host", :hostname => "test_host", :state => 'on', :ext_management_system => @ems)
      @vm_template = FactoryGirl.create(:template_vmware, :name => "template", :ext_management_system => @ems, :host => @host)
      @hardware    = FactoryGirl.create(:hardware, :vm_or_template => @vm_template, :guest_os => "winxppro", :memory_cpu => 512, :numvcpus => 2)
      @switch      = FactoryGirl.create(:switch, :name => 'vSwitch0', :ports => 32, :host => @host)
      @lan         = FactoryGirl.create(:lan, :name => "VM Network", :switch => @switch)
      @ethernet    = FactoryGirl.create(:guest_device, :hardware => @hardware, :lan => @lan, :device_type => 'ethernet', :controller_type => 'ethernet', :address => '00:50:56:ba:10:6b', :present => false, :start_connected => true)

      @params      = [
        "1.1",
        "name=template",
        "vm_name=target",
        "owner_email=admin@manageiq.com|owner_last_name=admin|owner_first_name=admin",
        "network_location=Internal|cc=001",
        "testvar1=value1|testvar2=value2",
        "",
        ""
      ]
    end

    it "should create an MiqProvisionRequest when calling WS version 1.0" do
      invoke(:EVM_provision_request, "template", "target", false, "cc|001|environment|test", "").should be_true
    end

    it "should create an MiqProvisionRequest when calling WS version 1.1" do
      invoke(:EVM_provision_request_ex, *@params).should be_true

      MiqRequest.count.should == 1
      r = MiqRequest.first
      r.options[:ws_values].should have_key(:testvar1)
      r.options[:ws_values][:testvar1].should == "value1"
    end

    it "should create an MiqProvisionRequest when calling WS version 2.0 with nil options" do
      params = @params[0,5]
      params << nil
      result = invoke(:VmProvisionRequest, *params)
      result.should be_an_instance_of(VmdbwsSupport::ProxyMiqProvisionRequest)
    end

    it "should create an MiqProvisionRequest when calling WS version 2.0 with a ProvisionOptions object" do
      params = @params[0,5]
      params << VmdbwsSupport::ProvisionOptions.new(:values => @params[5], :ems_custom_attributes => @params[6], :miq_custom_attributes => @params[7])
      req = invoke(:VmProvisionRequest, *params)
      req.should be_an_instance_of(VmdbwsSupport::ProxyMiqProvisionRequest)
      req.approval_state.should == 'pending_approval'
      req.request_state.should  == 'pending'
      req.status.should         == 'Ok'
      req.requester_name.should == 'admin'
      req.userid.should         == 'admin'

      req.request_type.should   == 'template'
      req.source_type.should    == 'template'
    end

    context "with a valid MiqProvisionRequest" do
      before(:each) do
        Classification.seed

        params = @params[0,5]
        params << VmdbwsSupport::ProvisionOptions.new(:values => @params[5], :ems_custom_attributes => @params[6], :miq_custom_attributes => @params[7])
        @proxy_request = invoke(:VmProvisionRequest, *params)
        @miq_request = MiqRequest.find_by_id(@proxy_request.id)

        req_task_attribs = @miq_request.attributes.dup
        req_task_attribs['state'] = req_task_attribs.delete('request_state')
        (req_task_attribs.keys - MiqRequestTask.column_names + ['created_on', 'updated_on', 'type']).each {|key| req_task_attribs.delete(key)}

        req_task_attribs['options'][:pass] = 1
        vm001 = FactoryGirl.create(:vm_vmware,   :name => "vm001",  :location => "vm001/vm001.vmx", :ext_management_system => @ems, :host => @host)
        @miq_request.miq_request_tasks << FactoryGirl.create(:miq_provision, req_task_attribs)
        @miq_request.miq_request_tasks.first.destination = vm001

        # Since the request has been updated get an updated copy through the WS
        @proxy_request = invoke(:GetVmProvisionRequest, @proxy_request.id)
      end

      it 'should return the valid relationships to VMs and Request tasks' do
        @proxy_request.source.should be_an_instance_of(VmdbwsSupport::VmList)

        @proxy_request.miq_request_tasks.should be_kind_of(Array)
        @proxy_request.miq_request_tasks.each {|p| p.should be_an_instance_of(VmdbwsSupport::MiqProvisionTaskList)}

        @proxy_request.vms.should be_kind_of(Array)
        @proxy_request.vms.each {|v| v.should be_an_instance_of(VmdbwsSupport::VmList)}
      end

      it 'should get an updated request object' do
        r = MiqRequest.find_by_id(@proxy_request.id)
        @proxy_request.request_state.should == r.request_state

        r.update_attribute(:request_state, 'finished')
        @proxy_request.request_state.should_not == r.request_state

        prov = invoke(:GetVmProvisionRequest, @proxy_request.id)
        prov.should be_an_instance_of(VmdbwsSupport::ProxyMiqProvisionRequest)
        prov.request_state.should == r.request_state
      end

      it 'should provide the options hash column as an array' do
        @proxy_request.request_options.should be_kind_of(Array)
        @proxy_request.request_options.first.should be_kind_of(VmdbwsSupport::KeyValueStruct)
        options = {}
        @proxy_request.request_options.each {|opt| options[opt.key] = opt.value}

        %w{number_of_vms vm_memory owner_email placement_auto miq_request_dialog_name}.each do |key|
          options.should have_key(key)
          options[key].should_not be_blank
        end

        %w{vm_tags ws_values networks}.each do |key|
          options.should_not have_key(key)
        end
      end

      it 'should provide the selected tags as an array' do
        @proxy_request.request_tags.should be_kind_of(Array)
        @proxy_request.request_tags.should have(2).things
        @proxy_request.request_tags.first.should be_kind_of(VmdbwsSupport::Tag)
      end

      it 'should return MiqProvisionTask instance' do
        task_id = @proxy_request.miq_request_tasks.first.id
        @proxy_task = invoke(:GetVmProvisionTask, task_id)
        @proxy_task.should be_kind_of(VmdbwsSupport::ProxyMiqProvisionTask)

        @proxy_request.request_options.should be_kind_of(Array)

        @proxy_task.request_tags.should be_kind_of(Array)
        @proxy_task.request_tags.should have(2).things
        @proxy_task.request_tags.first.should be_kind_of(VmdbwsSupport::Tag)
      end
    end
  end
end

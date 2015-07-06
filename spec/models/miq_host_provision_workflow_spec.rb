require "spec_helper"

silence_warnings { MiqHostProvisionWorkflow.const_set("DIALOGS_VIA_AUTOMATE", false) }

describe MiqHostProvisionWorkflow do

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

        @templateFields = "mac_address=aa:bb:cc:dd:ee:ff|ipmi_address=127.0.0.1|"
        @requester      = "owner_email=tester@miq.com|owner_first_name=tester|owner_last_name=tester"
        @hostFields = <<-HOST_FIELDS
                          pxe_server_id=127.0.0.1|
                          pxe_image_id=ESXi 4.1-260247|
                          root_password=smartvm|
                          addr_mode=dhcp|
                      HOST_FIELDS

        FactoryGirl.create(:miq_dialog_host_provision)
      end

      context "Without a Valid IPMI Host," do
        it "should not create an MiqRequest when calling from_ws" do
          lambda { MiqHostProvisionWorkflow.from_ws("1.1", "admin", @templateFields, @hostFields, @requester, false, nil, nil)}.should raise_error(RuntimeError)
        end
      end

      context "With a Valid IPMI Host," do
        before(:each) do
          ems        = FactoryGirl.create(:ems_vmware,  :name => "Test EMS",  :zone => @zone)
          host       = FactoryGirl.create(:host_with_ipmi, :ext_management_system => ems)
          pxe_server = FactoryGirl.create(:pxe_server, :name => 'PXE on 127.0.0.1', :uri_prefix => 'nfs', :uri => 'nfs://127.0.0.1/srv/tftpboot')
          pxe_image  = FactoryGirl.create(:pxe_image, :name => 'VMware ESXi 4.1-260247', :pxe_server => pxe_server)
        end

        it "should create an MiqRequest when calling from_ws" do
          request = MiqHostProvisionWorkflow.from_ws("1.1", "admin", @templateFields, @hostFields, @requester, false, nil, nil)
          request.should be_a_kind_of(MiqRequest)
          opt = request.options
        end
      end
    end
  end
end

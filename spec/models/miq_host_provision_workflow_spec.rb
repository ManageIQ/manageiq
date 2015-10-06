require "spec_helper"

silence_warnings { MiqHostProvisionWorkflow.const_set("DIALOGS_VIA_AUTOMATE", false) }

describe MiqHostProvisionWorkflow do
  include WorkflowSpecHelper
  context "seeded" do
    context "After setup," do
      before(:each) do
        @server = EvmSpecHelper.local_miq_server

        FactoryGirl.create(:user_admin)

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
          -> { MiqHostProvisionWorkflow.from_ws("1.1", "admin", @templateFields, @hostFields, @requester, false, nil, nil) }.should raise_error(RuntimeError)
        end
      end

      context "With a Valid IPMI Host," do
        before(:each) do
          ems        = FactoryGirl.create(:ems_vmware, :name => "Test EMS", :zone => @server.zone)
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

  describe "#make_request" do
    let(:host)  { FactoryGirl.create(:host) }
    let(:admin) { FactoryGirl.create(:user_with_group) }
    let(:alt_user) { FactoryGirl.create(:user_with_group) }
    it "creates and update a request" do
      EvmSpecHelper.local_miq_server
      stub_dialog(:get_pre_dialogs)
      stub_dialog(:get_dialogs)

      # if running_pre_dialog is set, it will run 'continue_request'
      workflow = described_class.new(values = {:running_pre_dialog => false}, admin.userid)

      expect(AuditEvent).to receive(:success).with(
        :event        => "host_provision_request_created",
        :target_class => "Host",
        :userid       => admin.userid,
        :message      => "Host Provisioning requested by <#{admin.userid}> for Host:#{[host.id].inspect}"
      )

      # creates a request

      # the dialogs populate this
      values.merge!(:src_host_ids => [host.id], :vm_tags => [])

      request = workflow.make_request(nil, values, admin.userid) # TODO: nil

      expect(request).to be_valid
      expect(request).to be_a_kind_of(MiqHostProvisionRequest)
      expect(request.request_type).to eq("host_pxe_install")
      expect(request.description).to eq("PXE install on [#{host.name}] from image []")
      expect(request.requester).to eq(admin)
      expect(request.userid).to eq(admin.userid)
      expect(request.requester_name).to eq(admin.name)

      # updates a request

      workflow = described_class.new(values, alt_user.userid)

      expect(AuditEvent).to receive(:success).with(
        :event        => "host_provision_request_updated",
        :target_class => "Host",
        :userid       => alt_user.userid,
        :message      => "Host Provisioning request updated by <#{alt_user.userid}> for Host:#{[host.id].inspect}"
      )
      workflow.make_request(request, values, alt_user.userid)
    end
  end
end

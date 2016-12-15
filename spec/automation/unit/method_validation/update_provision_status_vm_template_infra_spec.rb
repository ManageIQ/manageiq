describe "update_provision_status" do
  def build_resolve_path
    instance  = "/System/Request/Call_Method"
    namespace = "namespace=/ManageIQ/Infrastructure/VM/Provisioning/StateMachines"
    klass     = "class=VMProvision_Template"
    method    = "method=update_provision_status"
    "#{instance}?#{namespace}&#{klass}&#{method}"
  end

  let(:user) { FactoryGirl.create(:user_with_group) }
  let(:ws) { MiqAeEngine.instantiate("#{build_resolve_path}&#{@args}", user) }
  let(:miq_server) { EvmSpecHelper.local_miq_server }

  context "with a provision request object" do
    let(:ems)   { FactoryGirl.create(:ems_vmware_with_authentication) }
    let(:vm_template) { FactoryGirl.create(:template_vmware, :ext_management_system => ems) }
    let(:options) { {:src_vm_id => [vm_template.id, vm_template.name], :pass => 1} }
    let(:miq_provision_request) do
      FactoryGirl.create(:miq_provision_request,
                         :provision_type => 'template',
                         :state => 'pending', :status => 'Ok',
                         :src_vm_id => vm_template.id,
                         :requester => user)
    end

    let(:provision) do
      FactoryGirl.create(:miq_provision_vmware, :provision_type => 'template',
                         :state => 'pending', :status => 'Ok',
                         :miq_request => miq_provision_request,
                         :options => options, :userid => user.userid)
    end

    it "method succeeds" do
      @args = "status=fred&ae_result=ok&MiqProvision::miq_provision=#{provision.id}&" \
              "MiqServer::miq_server=#{miq_server.id}"
      add_call_method
      ws
      expect(provision.reload.status).to eq('Ok')
    end

    it "request message set properly" do
      @args = "status=fred&ae_result=ok&MiqProvision::miq_provision=#{provision.id}&" \
              "MiqServer::miq_server=#{miq_server.id}"
      add_call_method
      ws
      expect(provision.reload.status).to eq('Ok')
      msg = "[#{miq_server.name}] VM [] Step [] Status [#{provision.message}] Message [] "
      expect(miq_provision_request.reload.message).to eq(msg)
    end
    it "method succeeds with error" do
      type = :automate_user_error
      FactoryGirl.create(:notification_type, :name => type)

      @args = "status=fred&ae_result=error&MiqProvision::miq_provision=#{provision.id}&" \
              "MiqServer::miq_server=#{miq_server.id}"
      expect(Notification.count).to eq(0)
      add_call_method
      ws
      expect(provision.reload.status).to eq('Ok')
      expect(Notification.find_by(:notification_type_id => NotificationType.find_by_name(type).id)).not_to be_nil
    end
  end

  context "without a provision object" do
    it "method fails" do
      @args = "status=fred&ae_result=ok&MiqServer::miq_server=#{miq_server.id}"
      add_call_method
      ws
      expect(ws.root).to be_nil
    end
  end
end

describe "update_serviceprovision_status" do
  def build_resolve_path
    instance  = "/System/Request/Call_Method"
    namespace = "namespace=/ManageIQ/Service/Provisioning/StateMachines"
    klass     = "class=ServiceProvision_Template"
    method    = "method=update_serviceprovision_status"
    "#{instance}?#{namespace}&#{klass}&#{method}"
  end

  let(:user) { FactoryGirl.create(:user_with_group) }
  let(:ws) { MiqAeEngine.instantiate("#{build_resolve_path}&#{@args}", user) }
  let(:miq_server) { EvmSpecHelper.local_miq_server }
  let(:miq_request_task) do
    FactoryGirl.create(:miq_request_task, :destination => service_orchestration,
                       :miq_request => request, :state => 'fred')
  end

  let(:request) do
    FactoryGirl.create(:service_template_provision_request, :requester => user)
  end

  let(:service_orchestration) { FactoryGirl.create(:service_orchestration) }

  context "with a stp request object" do
    it "method succeeds" do
      @args = "status=fred&ae_result=ok&MiqRequestTask::service_template_provision_task=#{miq_request_task.id}&" \
              "MiqServer::miq_server=#{miq_server.id}"
      add_call_method
      ws
      expect(request.reload.status).to eq('Ok')
    end

    it "request message set properly" do
      @args = "status=fred&ae_result=ok&MiqRequestTask::service_template_provision_task=#{miq_request_task.id}&" \
              "MiqServer::miq_server=#{miq_server.id}"
      add_call_method
      ws
      msg = "Server [#{miq_server.name}] Service [#{service_orchestration.name}] Step [] Status [fred] Message [] "
      expect(request.reload.message).to eq(msg)
    end

    it "request message set properly with error" do
      type = :automate_user_error
      FactoryGirl.create(:notification_type, :name => type)

      @args = "status=fred&ae_result=error&MiqRequestTask::service_template_provision_task=#{miq_request_task.id}&" \
              "MiqServer::miq_server=#{miq_server.id}"
      expect(Notification.count).to eq(0)
      add_call_method
      ws
      msg = "Server [#{miq_server.name}] Service [#{service_orchestration.name}] Step [] Status [fred] Message [] "
      expect(request.reload.message).to eq(msg)
      expect(Notification.find_by(:notification_type_id => NotificationType.find_by_name(type).id)).not_to be_nil
    end
  end

  context "without a stp request object" do
    it "method fails" do
      @args = "status=fred&ae_result=ok&MiqServer::miq_server=#{miq_server.id}"
      add_call_method
      expect(ws.root).to be_nil
    end
  end
end

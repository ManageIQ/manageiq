describe "update_serviceprovision_status" do
  let(:user) { FactoryGirl.create(:user_with_group) }
  let(:miq_server) { EvmSpecHelper.local_miq_server }
  let(:miq_request_task) do
    FactoryGirl.create(:miq_request_task, :destination => service_orchestration,
                       :miq_request => request, :state => 'fred')
  end
  let(:request) do
    FactoryGirl.create(:service_template_provision_request, :requester => user)
  end
  let(:service_orchestration) { FactoryGirl.create(:service_orchestration) }

  context "Service Class" do
    let(:ws) do
      MiqAeEngine.instantiate("/System/Request/Call_Method?namespace=ManageIQ/Service/Provisioning/StateMachines&" \
                              "class=ServiceProvision_Template&method=update_serviceprovision_status&#{@args}", user)
    end

    it "Service Class method succeeds" do
      @args = "status=fred&ae_result=ok&MiqRequestTask::service_template_provision_task=#{miq_request_task.id}&" \
              "MiqServer::miq_server=#{miq_server.id}"
      add_call_method
      ws
      expect(request.reload.status).to eq('Ok')
    end

    it "Service Class request message set properly" do
      @args = "status=fred&ae_result=ok&MiqRequestTask::service_template_provision_task=#{miq_request_task.id}&" \
              "MiqServer::miq_server=#{miq_server.id}"
      add_call_method
      ws
      msg = "Server [#{miq_server.name}] Service [#{service_orchestration.name}] Step [] Status [fred] Message [] "
      expect(request.reload.message).to eq(msg)
    end

    it "Service Class method fails" do
      @args = "status=fred&ae_result=ok&MiqServer::miq_server=#{miq_server.id}"
      add_call_method
      expect(ws.root).to be_nil
    end
  end

  context "Cloud Orchestration Class" do
    let(:ws) do
      MiqAeEngine.instantiate("/System/Request/Call_Method?namespace=ManageIQ/Cloud/Orchestration/Provisioning" \
                              "/StateMachines&class=Provision&method=update_serviceprovision_status&#{@args}", user)
    end

    it "Cloud Orchestration Class method succeeds" do
      @args = "status=fred&ae_result=ok&MiqRequestTask::service_template_provision_task=#{miq_request_task.id}&" \
              "MiqServer::miq_server=#{miq_server.id}"
      add_call_method
      ws
      expect(request.reload.status).to eq('Ok')
    end

    it "Cloud Orchestration Class request message set properly" do
      @args = "status=fred&ae_result=ok&MiqRequestTask::service_template_provision_task=#{miq_request_task.id}&" \
              "MiqServer::miq_server=#{miq_server.id}"
      add_call_method
      ws
      msg = "Server [#{miq_server.name}] Service [#{service_orchestration.name}] Step [] Status [fred] Message [] "
      expect(request.reload.message).to eq(msg)
    end

    it "Cloud Orchestration Class method fails" do
      @args = "status=fred&ae_result=ok&MiqServer::miq_server=#{miq_server.id}"
      add_call_method
      expect(ws.root).to be_nil
    end
  end
  context "AnsibleTower Class" do
    let(:ws) do
      MiqAeEngine.instantiate("/System/Request/Call_Method?namespace=ManageIQ/ConfigurationManagement" \
                              "/AnsibleTower/Service/Provisioning/StateMachines&class=Provision&" \
                              "method=update_serviceprovision_status&#{@args}", user)
    end

    it "AnsibleTower Class method succeeds" do
      @args = "status=fred&ae_result=ok&MiqRequestTask::service_template_provision_task=#{miq_request_task.id}&" \
              "MiqServer::miq_server=#{miq_server.id}"
      add_call_method
      ws
      expect(request.reload.status).to eq('Ok')
    end

    it "AnsibleTower Class request message set properly" do
      @args = "status=fred&ae_result=ok&MiqRequestTask::service_template_provision_task=#{miq_request_task.id}&" \
              "MiqServer::miq_server=#{miq_server.id}"
      add_call_method
      ws
      msg = "Server [#{miq_server.name}] Service [#{service_orchestration.name}] Step [] Status [fred] Message [] "
      expect(request.reload.message).to eq(msg)
    end

    it "AnsibleTower Class method fails" do
      @args = "status=fred&ae_result=ok&MiqServer::miq_server=#{miq_server.id}"
      add_call_method
      expect(ws.root).to be_nil
    end
  end
end

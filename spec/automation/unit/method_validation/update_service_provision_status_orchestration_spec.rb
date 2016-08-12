describe "update_serviceprovision_status" do
  let(:miq_request_task) do
    FactoryGirl.create(:miq_request_task, :destination => service_orchestration,
                       :miq_request => request, :state => 'fred')
  end

  let(:request) do
    FactoryGirl.create(:service_template_provision_request, :requester => user)
  end

  let(:service_orchestration) { FactoryGirl.create(:service_orchestration) }
  let(:user)                  { FactoryGirl.create(:user_with_group) }

  context "with a stp request object" do
    let(:ws)                    { MiqAeEngine.instantiate("/System/Request/Call_Method?namespace=/ManageIQ/Cloud/Orchestration/Provisioning/StateMachines&status=fred&class=Provision&method=update_serviceprovision_status&ae_result=ok&MiqRequestTask::service_template_provision_task=#{miq_request_task.id}", user) }
    it "method succeeds" do
      add_call_method
      ws
      expect(request.reload.status).to eq('Ok')
    end
  end

  context "without a stp request object" do
    let(:ws) { MiqAeEngine.instantiate("/System/Request/Call_Method?namespace=/ManageIQ/Cloud/Orchestration/Provisioning/StateMachines&status=fred&class=Provision&method=update_serviceprovision_status&ae_result=ok", user) }
    it "method fails" do
      add_call_method
      expect(ws.root).to be_nil
    end
  end
end

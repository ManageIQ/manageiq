RSpec.describe OrchestrationStackReconfigureTask do
  let(:user)     { FactoryBot.create(:user_with_group) }
  let(:template) { FactoryBot.create(:service_template, :name => 'Test Template') }
  let(:service)  { FactoryBot.create(:service, :name => 'Test Service', :service_template => template) }
  let(:stack)    { FactoryBot.create(:orchestration_stack) }

  let(:request) do
    ServiceReconfigureRequest.create(:requester    => user,
                                     :options      => {:src_id => service.id},
                                     :request_type => 'service_reconfigure')
  end

  # parent ServiceReconfigureTask — source is the Service
  let(:parent_task) do
    ServiceReconfigureTask.create(:userid       => user.userid,
                                  :miq_request  => request,
                                  :source       => service,
                                  :request_type => 'service_reconfigure')
  end

  # child OrchestrationStackReconfigureTask — source is the stack
  let(:task) do
    OrchestrationStackReconfigureTask.create(:userid          => user.userid,
                                             :miq_request     => request,
                                             :miq_request_task => parent_task,
                                             :source          => stack,
                                             :request_type    => 'orchestration_stack_reconfigure')
  end

  describe "#before_ae_starts" do
    context "when task is pending" do
      it "transitions task to active" do
        task # ensure persisted
        task.before_ae_starts({})
        expect(task.reload.state).to eq("active")
      end

      it "rolls up to set service lifecycle_state to 'provisioning'" do
        task # ensure persisted
        task.before_ae_starts({})
        expect(service.reload.lifecycle_state).to eq("provisioning")
      end
    end

    context "when task is already active" do
      before { task.update!(:state => "active") }

      it "does not call update_and_notify_parent" do
        expect(task).not_to receive(:update_and_notify_parent)
        task.before_ae_starts({})
      end
    end
  end

  describe "#after_ae_delivery" do
    before { task.update!(:state => "active") }

    context "when ae_result is 'ok'" do
      it "transitions task to finished with Ok status" do
        task.after_ae_delivery('ok')
        expect(task.reload.state).to eq("finished")
        expect(task.reload.status).to eq("Ok")
      end

      it "rolls up to set service lifecycle_state to 'provisioned'" do
        task.after_ae_delivery('ok')
        expect(service.reload.lifecycle_state).to eq("provisioned")
      end
    end

    context "when ae_result is 'error'" do
      it "transitions task to finished with Error status" do
        task.after_ae_delivery('error')
        expect(task.reload.state).to eq("finished")
        expect(task.reload.status).to eq("Error")
      end

      it "rolls up to set service lifecycle_state to 'error_in_provisioning'" do
        task.after_ae_delivery('error')
        expect(service.reload.lifecycle_state).to eq("error_in_provisioning")
      end
    end

    context "when ae_result is 'retry'" do
      it "is a no-op" do
        expect(task).not_to receive(:update_and_notify_parent)
        task.after_ae_delivery('retry')
      end
    end

    context "when the miq_request is already finished" do
      before { request.update!(:request_state => 'finished') }

      it "is a no-op" do
        expect(task).not_to receive(:update_and_notify_parent)
        task.after_ae_delivery('ok')
      end
    end
  end
end

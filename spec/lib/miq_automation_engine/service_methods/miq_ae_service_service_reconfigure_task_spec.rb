describe MiqAeMethodService::MiqAeServiceServiceReconfigureTask do
  include Spec::Support::AutomationHelper

  before(:each) do
    method_script   = "$evm.root['result'] = $evm.root['service_reconfigure_task'].status"
    create_ae_model_with_method(:method_script => method_script, :ae_class => 'AUTOMATE',
                                :ae_namespace  => 'EVM', :instance_name => 'test1',
                                :method_name   => 'test', :name => 'TEST_DOMAIN')
  end

  let(:ae_method) { ::MiqAeMethod.first }
  let(:options)   { {} }
  let(:user)      { FactoryGirl.create(:user_with_group) }
  let(:task)      do
    FactoryGirl.create(:service_reconfigure_task,
                       :state        => 'pending',
                       :status       => 'Ok',
                       :request_type => 'service_reconfigure',
                       :options      => options)
  end

  def invoke_ae
    MiqAeEngine.instantiate("/EVM/AUTOMATE/test1?ServiceReconfigureTask::service_reconfigure_task=#{task.id}", user)
  end

  context "#status" do
    it "returns 'ok' when state is finished" do
      task.update_attributes(:state => "finished")

      expect(invoke_ae.root('result')).to eq('ok')
    end

    it "returns 'retry' when state is pending" do
      task.update_attributes(:state => "pending")

      expect(invoke_ae.root('result')).to eq('retry')
    end
  end
end

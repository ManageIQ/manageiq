module MiqAeServiceMiqRequestTaskSpec
  describe MiqAeMethodService::MiqAeServiceMiqRequestTask do
    before(:each) do
      @user = FactoryGirl.create(:user_with_group)
      Spec::Support::MiqAutomateHelper.create_service_model_method('SPEC_DOMAIN', 'EVM', 'AUTOMATE', 'test1', 'test')
      @ae_method     = ::MiqAeMethod.first
      @ae_result_key = 'foo'

      @miq_request_task = FactoryGirl.create(:miq_request_task, :status => 'Ok')
    end

    def invoke_ae
      MiqAeEngine.instantiate("/EVM/AUTOMATE/test1?MiqRequestTask::miq_request_task=#{@miq_request_task.id}", @user)
    end

    it "#execute" do
      method   = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_request_task'].execute"
      @ae_method.update_attributes(:data => method)
      expect_any_instance_of(MiqRequestTask).to receive(:execute_queue).once
      expect(invoke_ae.root(@ae_result_key)).to be_truthy
    end

    it "#miq_request" do
      method   = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_request_task'].miq_request"
      @ae_method.update_attributes(:data => method)

      user        = FactoryGirl.create(:user)
      miq_request = FactoryGirl.create(:vm_migrate_request, :requester => user)
      @miq_request_task.update_attributes(:miq_request => miq_request)

      result = invoke_ae.root(@ae_result_key)
      expect(result).to be_kind_of(MiqAeMethodService::MiqAeServiceMiqRequest)
      expect(result.id).to eq(miq_request.id)
    end

    it "#options" do
      method   = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_request_task'].options"
      @ae_method.update_attributes(:data => method)
      options = {:a => 1, :b => 'two'}
      expect_any_instance_of(MiqRequestTask).to receive(:options).once.and_return(options)
      expect(invoke_ae.root(@ae_result_key)).to eq(options)
    end

    it "#get_option" do
      key = 'key1'
      method   = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_request_task'].get_option('#{key}')"
      @ae_method.update_attributes(:data => method)
      value = 'three hundred'
      expect_any_instance_of(MiqRequestTask).to receive(:get_option).with(key).once.and_return(value)
      expect(invoke_ae.root(@ae_result_key)).to eq(value)
    end

    it "#get_option_last" do
      key = 'key1'
      method   = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_request_task'].get_option_last('#{key}')"
      @ae_method.update_attributes(:data => method)
      value = 'three hundred'
      expect_any_instance_of(MiqRequestTask).to receive(:get_option_last).with(key).once.and_return(value)
      expect(invoke_ae.root(@ae_result_key)).to eq(value)
    end

    it "#set_option" do
      options = {:a => 1, :b => 'two'}
      @miq_request_task.update_attributes(:options => options)
      key     = 'foo'
      value   = 'bar'
      method   = "$evm.root['miq_request_task'].set_option('#{key}', '#{value}')"
      @ae_method.update_attributes(:data => method)
      invoke_ae
      new_options = options.dup
      new_options[key] = value
      expect(@miq_request_task.reload.options).to eq(new_options)
    end

    it "#get_tag" do
      category = 'category1'
      method   = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_request_task'].get_tag('#{category}')"
      @ae_method.update_attributes(:data => method)
      value = 'three hundred'
      expect_any_instance_of(MiqRequestTask).to receive(:get_tag).with(category).once.and_return(value)
      expect(invoke_ae.root(@ae_result_key)).to eq(value)
    end

    it "#get_tags" do
      method   = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_request_task'].get_tags"
      @ae_method.update_attributes(:data => method)
      tags = ['tag1', 'tag2']
      expect_any_instance_of(MiqRequestTask).to receive(:get_tags).once.and_return(tags)
      expect(invoke_ae.root(@ae_result_key)).to eq(tags)
    end

    it "#get_classification" do
      category = 'category1'
      method   = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_request_task'].get_classification('#{category}')"
      @ae_method.update_attributes(:data => method)
      value = 'three hundred'
      expect_any_instance_of(MiqRequestTask).to receive(:get_classification).with(category).once.and_return(value)
      expect(invoke_ae.root(@ae_result_key)).to eq(value)
    end

    it "#get_classifications" do
      method   = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_request_task'].get_classifications"
      @ae_method.update_attributes(:data => method)
      classifications = ['classification1', 'classification2']
      expect_any_instance_of(MiqRequestTask).to receive(:get_classifications).once.and_return(classifications)
      expect(invoke_ae.root(@ae_result_key)).to eq(classifications)
    end

    context "#message=" do
      before(:each) do
        @message = 'message1'
        method   = "$evm.root['miq_request_task'].message = '#{@message}'"
        @ae_method.update_attributes(:data => method)
      end

      it "should call update_and_notify_parent when miq_request_task.state != 'finished'" do
        @miq_request_task.update_attributes(:state => 'ok')
        expect_any_instance_of(MiqRequestTask).to receive(:update_and_notify_parent).with(:message => @message).once
        invoke_ae
      end

      it "should not call update_and_notify_parent when miq_request_task.state == 'finished'" do
        @miq_request_task.update_attributes(:state => 'finished')
        expect_any_instance_of(MiqRequestTask).to receive(:update_and_notify_parent).with(:message => @message).never
        invoke_ae
      end
    end

    it "#finished" do
      message = 'message1'
      method   = "$evm.root['miq_request_task'].finished('#{message}')"
      @ae_method.update_attributes(:data => method)
      expect_any_instance_of(MiqRequestTask).to receive(:update_and_notify_parent).with(:state => 'finished', :message => message).once
      invoke_ae
    end
  end
end

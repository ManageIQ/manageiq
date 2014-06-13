require "spec_helper"

module MiqAeServiceMiqRequestTaskSpec
  describe MiqAeMethodService::MiqAeServiceMiqRequestTask do
    before(:each) do
      MiqAutomateHelper.create_service_model_method('SPEC_DOMAIN', 'EVM',
                                                    'AUTOMATE', 'test1', 'test')
      @ae_method     = ::MiqAeMethod.find(:first)
      @ae_result_key = 'foo'

      @miq_request_task = FactoryGirl.create(:miq_request_task, :status => 'Ok')
    end

    def invoke_ae
      MiqAeEngine.instantiate("/EVM/AUTOMATE/test1?MiqRequestTask::miq_request_task=#{@miq_request_task.id}")
    end

    it "#execute" do
      method   = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_request_task'].execute"
      @ae_method.update_attributes(:data => method)
      MiqRequestTask.any_instance.should_receive(:execute_queue).once
      invoke_ae.root(@ae_result_key).should be_true
    end

    it "#miq_request" do
      method   = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_request_task'].miq_request"
      @ae_method.update_attributes(:data => method)

      fred          = FactoryGirl.create(:user, :name => 'Fred Flintstone',  :userid => 'fred')
      approver_role = FactoryGirl.create(:ui_task_set_approver)
      miq_request   = FactoryGirl.create(:miq_request, :requester => fred)
      @miq_request_task.update_attributes(:miq_request => miq_request)

      result = invoke_ae.root(@ae_result_key)
      result.should be_kind_of(MiqAeMethodService::MiqAeServiceMiqRequest)
      result.id.should == miq_request.id
    end


    it "#options" do
      method   = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_request_task'].options"
      @ae_method.update_attributes(:data => method)
      options = { :a => 1, :b => 'two' }
      MiqRequestTask.any_instance.should_receive(:options).once.and_return(options)
      invoke_ae.root(@ae_result_key).should == options
    end

    it "#get_option" do
      key = 'key1'
      method   = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_request_task'].get_option('#{key}')"
      @ae_method.update_attributes(:data => method)
      value = 'three hundred'
      MiqRequestTask.any_instance.should_receive(:get_option).with(key).once.and_return(value)
      invoke_ae.root(@ae_result_key).should == value
    end

    it "#get_option_last" do
      key = 'key1'
      method   = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_request_task'].get_option_last('#{key}')"
      @ae_method.update_attributes(:data => method)
      value = 'three hundred'
      MiqRequestTask.any_instance.should_receive(:get_option_last).with(key).once.and_return(value)
      invoke_ae.root(@ae_result_key).should == value
    end

    it "#set_option" do
      options = { :a => 1, :b => 'two' }
      @miq_request_task.update_attributes(:options => options)
      key     = 'foo'
      value   = 'bar'
      method   = "$evm.root['miq_request_task'].set_option('#{key}', '#{value}')"
      @ae_method.update_attributes(:data => method)
      invoke_ae
      new_options = options.dup
      new_options[key] = value
      @miq_request_task.reload.options.should == new_options
    end

    it "#get_tag" do
      category = 'category1'
      method   = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_request_task'].get_tag('#{category}')"
      @ae_method.update_attributes(:data => method)
      value = 'three hundred'
      MiqRequestTask.any_instance.should_receive(:get_tag).with(category).once.and_return(value)
      invoke_ae.root(@ae_result_key).should == value
    end

    it "#get_tags" do
      method   = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_request_task'].get_tags"
      @ae_method.update_attributes(:data => method)
      tags = ['tag1', 'tag2']
      MiqRequestTask.any_instance.should_receive(:get_tags).once.and_return(tags)
      invoke_ae.root(@ae_result_key).should == tags
    end

    it "#get_classification" do
      category = 'category1'
      method   = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_request_task'].get_classification('#{category}')"
      @ae_method.update_attributes(:data => method)
      value = 'three hundred'
      MiqRequestTask.any_instance.should_receive(:get_classification).with(category).once.and_return(value)
      invoke_ae.root(@ae_result_key).should == value
    end

    it "#get_classifications" do
      method   = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_request_task'].get_classifications"
      @ae_method.update_attributes(:data => method)
      classifications = ['classification1', 'classification2']
      MiqRequestTask.any_instance.should_receive(:get_classifications).once.and_return(classifications)
      invoke_ae.root(@ae_result_key).should == classifications
    end

    context "#message=" do
      before(:each) do
        @message = 'message1'
        method   = "$evm.root['miq_request_task'].message = '#{@message}'"
        @ae_method.update_attributes(:data => method)
      end

      it "should call update_and_notify_parent when miq_request_task.state != 'finished'" do
        @miq_request_task.update_attributes(:state => 'ok')
        MiqRequestTask.any_instance.should_receive(:update_and_notify_parent).with(:message => @message).once
        invoke_ae
      end

      it "should not call update_and_notify_parent when miq_request_task.state == 'finished'" do
        @miq_request_task.update_attributes(:state => 'finished')
        MiqRequestTask.any_instance.should_receive(:update_and_notify_parent).with(:message => @message).never
        invoke_ae
      end
    end

    it "#finished" do
      message = 'message1'
      method   = "$evm.root['miq_request_task'].finished('#{message}')"
      @ae_method.update_attributes(:data => method)
      MiqRequestTask.any_instance.should_receive(:update_and_notify_parent).with(:state => 'finished', :message => message).once
      invoke_ae
    end

  end
end

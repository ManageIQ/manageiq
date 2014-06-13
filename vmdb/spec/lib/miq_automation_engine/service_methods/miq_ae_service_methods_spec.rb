require "spec_helper"

module MiqAeServiceMethodsSpec
  describe MiqAeMethodService::MiqAeServiceMethods do
    before(:each) do
      MiqAutomateHelper.create_service_model_method('SPEC_DOMAIN', 'EVM',
                                                    'AUTOMATE', 'test1', 'test')
      @ae_method     = ::MiqAeMethod.find(:first)
      @ae_result_key = 'foo'
    end

    def invoke_ae
      MiqAeEngine.instantiate("/EVM/AUTOMATE/test1")
    end

    context "exposes ActiveSupport methods" do
      it "nil#blank?" do
        method   = "$evm.root['#{@ae_result_key}'] = nil.blank?"
        @ae_method.update_attributes(:data => method)
        ae_object = invoke_ae.root(@ae_result_key)
        ae_object.should be_true
      end
    end

    it "#send_mail" do
      options = {
        :to       => "wilma@bedrock.gov",
        :from     => "fred@bedrock.gov",
        :body     => "What are we having for dinner?",
        :content_type => "text/fred",
        :subject  => "Dinner"
      }

      method   = "$evm.root['#{@ae_result_key}'] = $evm.execute(:send_email, #{options[:to].inspect}, #{options[:from].inspect}, #{options[:subject].inspect}, #{options[:body].inspect}, #{options[:content_type].inspect})"
      @ae_method.update_attributes(:data => method)
      MiqAeMethodService::MiqAeServiceMethods.with_constants :SYNCHRONOUS => true do
        GenericMailer.should_receive(:deliver).with(:automation_notification, options).once
        ae_object = invoke_ae.root(@ae_result_key)
        ae_object.should be_true
      end

      method   = "$evm.root['#{@ae_result_key}'] = $evm.execute(:send_email, #{options[:to].inspect}, #{options[:from].inspect}, #{options[:subject].inspect}, #{options[:body].inspect}, #{options[:content_type].inspect})"
      @ae_method.update_attributes(:data => method)
      MiqAeMethodService::MiqAeServiceMethods.with_constants :SYNCHRONOUS => false do
        MiqQueue.should_receive(:put).with(
          :class_name  => 'GenericMailer',
          :method_name => "deliver",
          :args        => [:automation_notification, options],
          :role        => "notifier",
          :zone        => nil).once
        ae_object = invoke_ae.root(@ae_result_key)
        ae_object.should be_true
      end
    end

    it "#snmp_trap_v1" do
      to      = "wilma@bedrock.gov"
      from    = "fred@bedrock.gov"
      inputs  = { :to => to, :from => from }
      method   = "$evm.root['#{@ae_result_key}'] = $evm.execute(:snmp_trap_v1, #{inputs.inspect})"
      @ae_method.update_attributes(:data => method)

      MiqAeMethodService::MiqAeServiceMethods.with_constants :SYNCHRONOUS => true do
        MiqSnmp.should_receive(:trap_v1).with(inputs).once
        ae_object = invoke_ae.root(@ae_result_key)
        ae_object.should be_true
      end

      MiqAeMethodService::MiqAeServiceMethods.with_constants :SYNCHRONOUS => false do
        MiqQueue.should_receive(:put).with(
          :class_name  => "MiqSnmp",
          :method_name => "trap_v1",
          :args        => [inputs],
          :role        => "notifier",
          :zone        => nil).once
        ae_object = invoke_ae.root(@ae_result_key)
        ae_object.should be_true
      end
    end

    it "#snmp_trap_v2" do
      to      = "wilma@bedrock.gov"
      from    = "fred@bedrock.gov"
      inputs  = { :to => to, :from => from }
      method   = "$evm.root['#{@ae_result_key}'] = $evm.execute(:snmp_trap_v2, #{inputs.inspect})"
      @ae_method.update_attributes(:data => method)

      MiqAeMethodService::MiqAeServiceMethods.with_constants :SYNCHRONOUS => true do
        MiqSnmp.should_receive(:trap_v2).with(inputs).once
        ae_object = invoke_ae.root(@ae_result_key)
        ae_object.should be_true
      end

      MiqAeMethodService::MiqAeServiceMethods.with_constants :SYNCHRONOUS => false do
        MiqQueue.should_receive(:put).with(
          :class_name  => "MiqSnmp",
          :method_name => "trap_v2",
          :args        => [inputs],
          :role        => "notifier",
          :zone        => nil).once
        ae_object = invoke_ae.root(@ae_result_key)
        ae_object.should be_true
      end
    end

    it "#vm_templates" do
      method   = "$evm.root['#{@ae_result_key}'] = $evm.execute(:vm_templates)"
      @ae_method.update_attributes(:data => method)

      invoke_ae.root(@ae_result_key).should be_empty

      v1 = FactoryGirl.create(:vm_vmware, :ems_id => 42, :vendor => 'vmware')
      t1 = FactoryGirl.create(:template_vmware, :ems_id => 42)
      ae_object = invoke_ae.root(@ae_result_key)
      ae_object.should be_kind_of(Array)
      ae_object.length.should == 1
      ae_object.first.id.should == t1.id
    end

    it "#active_miq_proxies" do
      method   = "$evm.root['#{@ae_result_key}'] = $evm.execute(:active_miq_proxies)"
      @ae_method.update_attributes(:data => method)

      invoke_ae.root(@ae_result_key).should be_empty

      a1 = FactoryGirl.create(:active_cos_proxy)
      i1 = FactoryGirl.create(:inactive_cos_proxy)
      ae_object = invoke_ae.root(@ae_result_key)
      ae_object.should be_kind_of(Array)
      ae_object.length.should == 1
      ae_object.first.id.should == a1.id
    end

    it "#category_exists?" do
      category = "flintstones"
      method   = "$evm.root['#{@ae_result_key}'] = $evm.execute(:category_exists?, #{category.inspect})"
      @ae_method.update_attributes(:data => method)

      invoke_ae.root(@ae_result_key).should be_false

      FactoryGirl.create(:classification, :name => category)
      invoke_ae.root(@ae_result_key).should be_true
    end

  end
end

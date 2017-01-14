module MiqAeServiceMethodsSpec
  describe MiqAeMethodService::MiqAeServiceMethods do
    before(:each) do
      @user = FactoryGirl.create(:user_with_group)
      Spec::Support::MiqAutomateHelper.create_service_model_method('SPEC_DOMAIN', 'EVM', 'AUTOMATE', 'test1', 'test')
      @ae_method     = ::MiqAeMethod.first
      @ae_result_key = 'foo'
    end

    def invoke_ae
      MiqAeEngine.instantiate("/EVM/AUTOMATE/test1", @user)
    end

    context "exposes ActiveSupport methods" do
      it "nil#blank?" do
        method   = "$evm.root['#{@ae_result_key}'] = nil.blank?"
        @ae_method.update_attributes(:data => method)
        ae_object = invoke_ae.root(@ae_result_key)
        expect(ae_object).to be_truthy
      end
    end

    it "#send_mail" do
      options = {
        :to           => "wilma@bedrock.gov",
        :from         => "fred@bedrock.gov",
        :body         => "What are we having for dinner?",
        :content_type => "text/fred",
        :subject      => "Dinner"
      }

      method   = "$evm.root['#{@ae_result_key}'] = $evm.execute(:send_email, #{options[:to].inspect}, #{options[:from].inspect}, #{options[:subject].inspect}, #{options[:body].inspect}, #{options[:content_type].inspect})"
      @ae_method.update_attributes(:data => method)
      MiqAeMethodService::MiqAeServiceMethods.with_constants :SYNCHRONOUS => true do
        expect(GenericMailer).to receive(:deliver).with(:automation_notification, options).once
        ae_object = invoke_ae.root(@ae_result_key)
        expect(ae_object).to be_truthy
      end

      method   = "$evm.root['#{@ae_result_key}'] = $evm.execute(:send_email, #{options[:to].inspect}, #{options[:from].inspect}, #{options[:subject].inspect}, #{options[:body].inspect}, #{options[:content_type].inspect})"
      @ae_method.update_attributes(:data => method)
      MiqAeMethodService::MiqAeServiceMethods.with_constants :SYNCHRONOUS => false do
        expect(MiqQueue).to receive(:put).with(
          :class_name  => 'GenericMailer',
          :method_name => "deliver",
          :args        => [:automation_notification, options],
          :role        => "notifier",
          :zone        => nil).once
        ae_object = invoke_ae.root(@ae_result_key)
        expect(ae_object).to be_truthy
      end
    end

    it "#snmp_trap_v1" do
      to      = "wilma@bedrock.gov"
      from    = "fred@bedrock.gov"
      inputs  = {:to => to, :from => from}
      method   = "$evm.root['#{@ae_result_key}'] = $evm.execute(:snmp_trap_v1, #{inputs.inspect})"
      @ae_method.update_attributes(:data => method)

      MiqAeMethodService::MiqAeServiceMethods.with_constants :SYNCHRONOUS => true do
        expect(MiqSnmp).to receive(:trap_v1).with(inputs).once
        ae_object = invoke_ae.root(@ae_result_key)
        expect(ae_object).to be_truthy
      end

      MiqAeMethodService::MiqAeServiceMethods.with_constants :SYNCHRONOUS => false do
        expect(MiqQueue).to receive(:put).with(
          :class_name  => "MiqSnmp",
          :method_name => "trap_v1",
          :args        => [inputs],
          :role        => "notifier",
          :zone        => nil).once
        ae_object = invoke_ae.root(@ae_result_key)
        expect(ae_object).to be_truthy
      end
    end

    it "#snmp_trap_v2" do
      to      = "wilma@bedrock.gov"
      from    = "fred@bedrock.gov"
      inputs  = {:to => to, :from => from}
      method   = "$evm.root['#{@ae_result_key}'] = $evm.execute(:snmp_trap_v2, #{inputs.inspect})"
      @ae_method.update_attributes(:data => method)

      MiqAeMethodService::MiqAeServiceMethods.with_constants :SYNCHRONOUS => true do
        expect(MiqSnmp).to receive(:trap_v2).with(inputs).once
        ae_object = invoke_ae.root(@ae_result_key)
        expect(ae_object).to be_truthy
      end

      MiqAeMethodService::MiqAeServiceMethods.with_constants :SYNCHRONOUS => false do
        expect(MiqQueue).to receive(:put).with(
          :class_name  => "MiqSnmp",
          :method_name => "trap_v2",
          :args        => [inputs],
          :role        => "notifier",
          :zone        => nil).once
        ae_object = invoke_ae.root(@ae_result_key)
        expect(ae_object).to be_truthy
      end
    end

    it "#vm_templates" do
      method   = "$evm.root['#{@ae_result_key}'] = $evm.execute(:vm_templates)"
      @ae_method.update_attributes(:data => method)

      expect(invoke_ae.root(@ae_result_key)).to be_empty

      v1 = FactoryGirl.create(:vm_vmware, :ems_id => 42, :vendor => 'vmware')
      t1 = FactoryGirl.create(:template_vmware, :ems_id => 42)
      ae_object = invoke_ae.root(@ae_result_key)
      expect(ae_object).to be_kind_of(Array)
      expect(ae_object.length).to eq(1)
      expect(ae_object.first.id).to eq(t1.id)
    end

    it "#category_exists?" do
      category = "flintstones"
      method   = "$evm.root['#{@ae_result_key}'] = $evm.execute(:category_exists?, #{category.inspect})"
      @ae_method.update_attributes(:data => method)

      expect(invoke_ae.root(@ae_result_key)).to be_falsey

      FactoryGirl.create(:classification, :name => category)
      expect(invoke_ae.root(@ae_result_key)).to be_truthy
    end

    def category_create_script
      <<-'RUBY'
      options = {:name => 'flintstones',
                 :description => 'testing'}
      $evm.root['foo'] = $evm.execute(:category_create, options)
      RUBY
    end

    it "#category_create" do
      @ae_method.update_attributes(:data => category_create_script)

      expect(invoke_ae.root(@ae_result_key)).to be_truthy
    end

    it "#tag_exists?" do
      ct = FactoryGirl.create(:classification_department_with_tags)
      method = "$evm.root['#{@ae_result_key}'] = $evm.execute(:tag_exists?, #{ct.name.inspect}, #{ct.entries.first.name.inspect})"
      @ae_method.update_attributes(:data => method)

      expect(invoke_ae.root(@ae_result_key)).to be_truthy
    end

    it "#tag_create" do
      ct = FactoryGirl.create(:classification_department_with_tags)
      method = "$evm.root['#{@ae_result_key}'] = $evm.execute(:tag_create, #{ct.name.inspect}, {:name => 'fred', :description => 'ABC'})"
      @ae_method.update_attributes(:data => method)

      expect(invoke_ae.root(@ae_result_key)).to be_truthy
      ct.reload
      expect(ct.entries.collect(&:name).include?('fred')).to be_truthy
    end
  end
end

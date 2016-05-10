module MiqAeServiceServiceTemplateSpec
  describe MiqAeMethodService::MiqAeServiceServiceTemplate do
    context "through an automation method" do
      before(:each) do
        MiqAutomateHelper.create_service_model_method('SPEC_DOMAIN', 'EVM',
                                                      'AUTOMATE', 'test1', 'test')
        @ae_method     = ::MiqAeMethod.first
        @ae_result_key = 'foo'
        @service_template   = FactoryGirl.create(:service_template)
        @user = FactoryGirl.create(:user_with_group)
      end

      def invoke_ae
        MiqAeEngine.instantiate("/EVM/AUTOMATE/test1?ServiceTemplate::service_template=#{@service_template.id}", @user)
      end

      context "#type_display" do
        it "with service_type of unknown" do
          method = "$evm.root['#{@ae_result_key}'] = $evm.root['service_template'].type_display "
          @ae_method.update_attributes(:data => method)
          type_display = invoke_ae.root(@ae_result_key)
          expect(type_display).to eq('Unknown')
        end

        it "with service_type of atomic" do
          @service_template.update_attributes(:service_type => 'atomic')
          method = "$evm.root['#{@ae_result_key}'] = $evm.root['service_template'].type_display "
          @ae_method.update_attributes(:data => method)
          type_display = invoke_ae.root(@ae_result_key)
          expect(type_display).to eq('Item')
        end

        it "with service_type of composite" do
          @service_template.update_attributes(:service_type => 'composite')
          method = "$evm.root['#{@ae_result_key}'] = $evm.root['service_template'].type_display "
          @ae_method.update_attributes(:data => method)
          type_display = invoke_ae.root(@ae_result_key)
          expect(type_display).to eq('Bundle')
        end
      end
    end

    context "associations" do
      before do
        service_template          = FactoryGirl.create(:service_template)
        @service_service_template  = MiqAeMethodService::MiqAeServiceServiceTemplate.find(service_template.id)
      end

      it "#services" do
        service = FactoryGirl.create(:service, :service_template_id => @service_service_template.id)
        first_service = @service_service_template.services.first

        expect(first_service).to    be_kind_of(MiqAeMethodService::MiqAeServiceService)
        expect(first_service.id).to eq(service.id)
      end

      context "with a service resource" do
        before do
          @service_resource = FactoryGirl.create(:service_resource,
                                                 :service_template_id => @service_service_template.id)
        end

        it "#service_resources" do
          first_service_resource = @service_service_template.service_resources.first

          expect(first_service_resource).to    be_kind_of(MiqAeMethodService::MiqAeServiceServiceResource)
          expect(first_service_resource.id).to eq(@service_resource.id)
        end

        it "#service_templates" do
          sub_service_template = FactoryGirl.create(:service_template)
          @service_resource.update_attributes(:resource => sub_service_template)
          first_service_template = @service_service_template.service_templates.first

          expect(first_service_template).to    be_kind_of(MiqAeMethodService::MiqAeServiceServiceTemplate)
          expect(first_service_template.id).to eq(sub_service_template.id)
        end
      end
    end

    context "cloud?" do
      it "vmware should be false" do
        st1   = FactoryGirl.create(:service_template, :prov_type => 'vmware')
        sst1 = MiqAeMethodService::MiqAeServiceServiceTemplate.find(st1.id)
        expect(sst1.cloud?).to be_false
      end

      it "amazon/openstack should be true" do
        st2   = FactoryGirl.create(:service_template, :prov_type => 'openstack')
        sst2 = MiqAeMethodService::MiqAeServiceServiceTemplate.find(st2.id)
        st3   = FactoryGirl.create(:service_template, :prov_type => 'amazon')
        sst3 = MiqAeMethodService::MiqAeServiceServiceTemplate.find(st3.id)
        expect(sst2.cloud?).to be_true
        expect(sst3.cloud?).to be_true
      end
    end
  end
end

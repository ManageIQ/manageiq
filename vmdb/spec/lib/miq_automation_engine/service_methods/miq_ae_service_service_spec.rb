require "spec_helper"

module MiqAeServiceServiceSpec
  describe MiqAeMethodService::MiqAeServiceService do
    before(:each) do
      MiqAutomateHelper.create_service_model_method('SPEC_DOMAIN', 'EVM',
                                                    'AUTOMATE', 'test1', 'test')
      @ae_method     = ::MiqAeMethod.find(:first)
      @ae_result_key = 'foo'

      @service   = FactoryGirl.create(:service, :name => "test_service", :description => "test_description")
    end

    def invoke_ae
      MiqAeEngine.instantiate("/EVM/AUTOMATE/test1?Service::service=#{@service.id}")
    end

    it "#remove_from_vmdb" do
      Service.count.should == 1
      method = "$evm.root['#{@ae_result_key}'] = $evm.root['service'].remove_from_vmdb"
      @ae_method.update_attributes(:data => method)
      ae_object = invoke_ae.root(@ae_result_key)
      Service.count.should == 0
    end

    it "#set the service name" do
      @service.name.should == 'test_service'
      method = "$evm.root['#{@ae_result_key}'] = $evm.root['service'].name = 'new_test_service' "
      @ae_method.update_attributes(:data => method)
      ae_object = invoke_ae.root(@ae_result_key)
      @service.reload
      @service.name.should == 'new_test_service'
    end

    it "#set the service description" do
      @service.description.should == 'test_description'
      method = "$evm.root['#{@ae_result_key}'] = $evm.root['service'].description = 'new_test_description' "
      @ae_method.update_attributes(:data => method)
      ae_object = invoke_ae.root(@ae_result_key)
      @service.reload
      @service.description.should == 'new_test_description'
    end

    context "#display=" do
      it "updates the display visibility" do
        @service.display = true
        @service.save

        method = "$evm.root['service'].display = false"
        @ae_method.update_attributes(:data => method)
        invoke_ae

        @service.reload
        @service.display.should be_false
      end
    end

    context "#parent_service=" do
      before(:each) do
        @parent = FactoryGirl.create(:service, :name => "parent_service")
      end

      it "updates the parent service" do
        method = "$evm.root['service'].parent_service = $evm.vmdb('service').find(#{@parent.id})"
        @ae_method.update_attributes(:data => method)
        invoke_ae

        @parent.reload
        @parent.direct_service_children.collect(&:id).should == [@service.id]
      end

      it "clears the parent service" do
        method = "$evm.root['service'].parent_service = nil"
        @ae_method.update_attributes(:data => method)
        invoke_ae

        @parent.reload
        @parent.direct_service_children.should == []
      end

      it "validates the parent service" do
        method = "$evm.root['service'].parent_service = 'validate'"
        @ae_method.update_attributes(:data => method)

        expect { invoke_ae }.to raise_error(MiqAeException::AbortInstantiation)
      end
    end

    context "#self.create" do
      it "creates a new service" do
        service_template = FactoryGirl.create(:service_template, :name => 'Dummy')
        service_name = 'service name'
        description = 'description'
        method = <<EOF
  service_template = $evm.vmdb('service_template').find(#{service_template.id})
  $evm.vmdb('service').create(:name             => '#{service_name}',
                              :description      => '#{description}',
                              :service_template => service_template)
EOF
        @ae_method.update_attributes(:data => method)
        invoke_ae

        service = Service.find_by_name(service_name)
        service.should_not be_nil
        service.name.should be == service_name
        service.description.should be == description
        service.service_template.should_not be_nil
        service.service_template.id.should be == service_template.id
      end

      it "requires a service name" do
        method = "$evm.vmdb('service').create()"
        @ae_method.update_attributes(:data => method)

        expect { invoke_ae }.to raise_error(MiqAeException::AbortInstantiation)
      end

      it "ignores attributes that cannot be overridden" do
        service_name = 'test service name'
        method = "$evm.vmdb('service').create(:name => '#{service_name}', :some_invalid_attr => 1)"
        @ae_method.update_attributes(:data => method)

        expect { invoke_ae }.to_not raise_error
        Service.find_by_name(service_name).should_not be_nil
      end
    end

    pending "Not yet implemented: specs" do
      it "#retires_on="
      it "#retirement_warn="
    end
  end
end

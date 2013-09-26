require "spec_helper"

module MiqAeServiceServiceSpec
  describe MiqAeMethodService::MiqAeServiceService do

    let(:service)         { FactoryGirl.create(:service, :name => "test_service", :description => "test_description") }
    let(:service_service) { MiqAeMethodService::MiqAeServiceService.find(service.id) }

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
      expect(Service.count).to eq(0)
    end

    it "#set the service name" do
      expect(@service.name).to eq('test_service')
      method = "$evm.root['#{@ae_result_key}'] = $evm.root['service'].name = 'new_test_service' "
      @ae_method.update_attributes(:data => method)
      ae_object = invoke_ae.root(@ae_result_key)
      @service.reload
      expect(@service.name).to eq('new_test_service')
    end

    it "#set the service description" do
      expect(@service.description).to eq('test_description')
      method = "$evm.root['#{@ae_result_key}'] = $evm.root['service'].description = 'new_test_description' "
      @ae_method.update_attributes(:data => method)
      ae_object = invoke_ae.root(@ae_result_key)
      @service.reload
      expect(@service.description).to eq('new_test_description')
    end

    context "#display=" do
      it "updates the display visibility" do
        @service.display = true
        @service.save

        method = "$evm.root['service'].display = false"
        @ae_method.update_attributes(:data => method)
        invoke_ae

        @service.reload
        expect(@service.display).to be_false
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
        expect(@parent.direct_service_children).to eq([])
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
        expect(service).not_to be_nil
        expect(service.name).to eq(service_name)
        expect(service.description).to eq(description)
        expect(service.service_template).not_to be_nil
        expect(service.service_template.id).to eq(service_template.id)
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
        expect(Service.find_by_name(service_name)).not_to be_nil
      end
    end

    it "#start_retirement" do
      expect(service_service.retirement_state).to be_nil
      service_service.start_retirement

      expect(service_service.retirement_state).to eq("retiring")
    end

    it "#retire_now" do
      expect(@service.retirement_state).to be_nil
      expect(MiqAeEvent).to receive(:raise_evm_event).once

      service_service.retire_now
    end

    it "#retire_service_resources" do
      ems = FactoryGirl.create(:ems_vmware, :zone => @zone)
      vm  = FactoryGirl.create(:vm_vmware, :ems_id => ems.id)
      service << vm
      #method = "$evm.root['#{@ae_result_key}'] = $evm.root['service'].retire_service_resources"


      #@ae_method.update_attributes(:data => method)
      expect(service.service_resources).to have(1).thing
      expect(service.service_resources.first.resource.respond_to?(:retire_now)).to be_true
      service_service.retire_service_resources
      #ae_object = invoke_ae.root(@ae_result_key)
    end

    it "#finish_retirement" do
      expect(service_service.retired).to be_nil
      expect(service_service.retirement_state).to be_nil
      expect(service_service.retires_on).to be_nil

      service_service.finish_retirement

      expect(service_service.retired).to be_true
      expect(service_service.retires_on).to eq(Date.today)
      expect(service_service.retirement_state).to eq("retired")
    end

    it "#is_or_being_retired - false" do
      expect(service_service.is_or_being_retired?).to be_false
    end

    it "#is_or_being_retired - true" do
      service_service.retirement_state = 'retiring'

      expect(service_service.is_or_being_retired?).to be_true
    end

    it "#retires_on - today" do
      service_service.retires_on = Date.today
      service.reload

      expect(service.retirement_due?).to be_true
    end

    it "#retires_on - tomorrow" do
      service_service.retires_on = Date.today + 1
      service.reload

      expect(service.retirement_due?).to be_false
    end

    it "#retirement_warn" do
      expect(service_service.retirement_warn).to be_nil
      service.retirement_last_warn = Date.today
      service_service.retirement_warn = 60
      service.reload

      expect(service_service.retirement_warn).to eq(60)
      expect(service.retirement_last_warn).to be_nil

    end
  end
end

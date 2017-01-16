module MiqAeServiceServiceSpec
  describe MiqAeMethodService::MiqAeServiceService do
    let(:service)         { FactoryGirl.create(:service, :name => "test_service", :description => "test_description") }
    let(:service_service) { MiqAeMethodService::MiqAeServiceService.find(service.id) }
    let(:user)            { FactoryGirl.create(:user_with_group) }

    before(:each) do
      Spec::Support::MiqAutomateHelper.create_service_model_method('SPEC_DOMAIN', 'EVM', 'AUTOMATE', 'test1', 'test')
      @ae_method     = ::MiqAeMethod.first
      @ae_result_key = 'foo'

      @service   = FactoryGirl.create(:service, :name => "test_service", :description => "test_description")
    end

    def invoke_ae
      MiqAeEngine.instantiate("/EVM/AUTOMATE/test1?Service::service=#{@service.id}", user)
    end

    it "#remove_from_vmdb" do
      expect(Service.count).to eq(1)
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
        expect(@service.display).to be_falsey
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
        expect(@parent.direct_service_children.collect(&:id)).to eq([@service.id])
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

        service = Service.find_by(:name => service_name)
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
        expect(Service.find_by(:name => service_name)).not_to be_nil
      end
    end

    it "#start_retirement" do
      expect(service_service.retirement_state).to be_nil
      service_service.start_retirement

      expect(service_service.retirement_state).to eq("retiring")
    end

    it "#retire_now" do
      expect(@service.retirement_state).to be_nil
      expect(MiqEvent).to receive(:raise_evm_event).once

      service_service.retire_now
    end

    it "#retire_service_resources" do
      ems = FactoryGirl.create(:ems_vmware, :zone => @zone)
      vm  = FactoryGirl.create(:vm_vmware, :ems_id => ems.id)
      service << vm
      # method = "$evm.root['#{@ae_result_key}'] = $evm.root['service'].retire_service_resources"

      # @ae_method.update_attributes(:data => method)
      expect(service.service_resources.size).to eq(1)
      expect(service.service_resources.first.resource.respond_to?(:retire_now)).to be_truthy
      service_service.retire_service_resources
      # ae_object = invoke_ae.root(@ae_result_key)
    end

    it "#finish_retirement" do
      expect(service_service.retired).to be_nil
      expect(service_service.retirement_state).to be_nil
      expect(service_service.retires_on).to be_nil

      service_service.finish_retirement

      expect(service_service.retired).to be_truthy
      expect(service_service.retires_on).to be_between(Time.zone.now - 1.hour, Time.zone.now + 1.second)
      expect(service_service.retirement_state).to eq("retired")
    end

    it "#retiring - false" do
      expect(service_service.retiring?).to be_falsey
    end

    it "#retiring? - true" do
      service_service.retirement_state = 'retiring'

      expect(service_service.retiring?).to be_truthy
    end

    it "#error_retiring? - false" do
      expect(service_service.error_retiring?).to be_falsey
    end

    it "#error_retiring? - true" do
      service_service.retirement_state = 'error'

      expect(service_service.error_retiring?).to be_truthy
    end

    it "#retires_on - today" do
      service.update_attributes(:retirement_last_warn => Date.today)
      service_service.retires_on = Time.zone.today
      service.reload
      expect(service.retirement_last_warn).to be_nil
      expect(service.retirement_due?).to be_truthy
    end

    it "#retires_on - tomorrow" do
      service.update_attributes(
        :retired              => true,
        :retirement_last_warn => Time.zone.today,
        :retirement_state     => "retiring"
      )
      service_service.retires_on = Time.zone.today + 1
      service.reload

      expect(service).to have_attributes(
        :retirement_last_warn => nil,
        :retired              => false,
        :retirement_state     => nil,
        :retirement_due?      => false
      )
    end

    it "#extend_retires_on - no retirement date set" do
      extend_days = 7
      Timecop.freeze(Time.zone.today) do
        service_service.extend_retires_on(extend_days)
        service.reload
        new_retires_on = Time.zone.today + extend_days
        expect(service.retires_on.day).to eq(new_retires_on.day)
      end
    end

    it "#extend_retires_on - future retirement date set" do
      Timecop.freeze(Time.zone.today) do
        service.update_attributes(
          :retired              => true,
          :retirement_last_warn => Time.zone.today,
          :retirement_state     => "retiring"
        )
        future_retires_on = Time.zone.today + 30
        service_service.retires_on = future_retires_on
        extend_days = 7
        service_service.extend_retires_on(extend_days, future_retires_on)
        service.reload

        expect(service).to have_attributes(
          :retirement_last_warn => nil,
          :retired              => false,
          :retirement_state     => nil,
          :retires_on           => future_retires_on + extend_days
        )
      end
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

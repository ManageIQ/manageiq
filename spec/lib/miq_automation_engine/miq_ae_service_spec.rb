module MiqAeServiceSpec
  include MiqAeMethodService

  describe MiqAeServiceObject do
    before do
      @object = double('object')
      @service = double('service')
      @service_object = MiqAeServiceObject.new(@object, @service)
    end

    context "#attributes" do
      before do
        allow(@object).to receive(:attributes).and_return('true'     => true,
                                             'false'    => false,
                                             'time'     => Time.parse('Aug 30, 2013'),
                                             'symbol'   => :symbol,
                                             'int'      => 1,
                                             'float'    => 1.1,
                                             'string'   => 'hello',
                                             'array'    => [1, 2, 3, 4],
                                             'password' => MiqAePassword.new('test'))
      end

      it "obscures passwords" do
        original_attributes = @object.attributes.dup
        attributes = @service_object.attributes
        expect(attributes['password']).to eq('********')
        expect(@object.attributes).to eq(original_attributes)
      end
    end

    context "#inspect" do
      it "returns the class, id and name" do
        allow(@object).to receive(:object_name).and_return('fred')
        regex = /#<MiqAeMethodService::MiqAeServiceObject:0x(\w+) name:.\"(?<name>\w+)\">/
        match = regex.match(@service_object.inspect)
        expect(match[:name]).to eq('fred')
      end
    end
  end

  describe MiqAeService do
    context "#service_model" do
      let(:miq_ae_service) { MiqAeService.new(double('ws', :persist_state_hash => {})) }
      let(:prefix) { "MiqAeMethodService::MiqAeService" }

      it "loads base model" do
        expect(miq_ae_service.service_model(:VmOrTemplate)).to   be(MiqAeMethodService::MiqAeServiceVmOrTemplate)
        expect(miq_ae_service.service_model(:vm_or_template)).to be(MiqAeMethodService::MiqAeServiceVmOrTemplate)
      end

      it "loads sub-classed model" do
        expect(miq_ae_service.service_model(:Vm)).to be(MiqAeMethodService::MiqAeServiceVm)
        expect(miq_ae_service.service_model(:vm)).to be(MiqAeMethodService::MiqAeServiceVm)
      end

      it "loads model with mapped name" do
        expect(miq_ae_service.service_model(:ems)).to be(MiqAeMethodService::MiqAeServiceExtManagementSystem)
      end

      it "loads name-spaced model by mapped name" do
        MiqAeMethodService::Deprecation.silence do
          expect(miq_ae_service.service_model(:ems_openstack)).to be(
            MiqAeMethodService::MiqAeServiceManageIQ_Providers_Openstack_CloudManager)
          expect(miq_ae_service.service_model(:vm_openstack)).to  be(
            MiqAeMethodService::MiqAeServiceManageIQ_Providers_Openstack_CloudManager_Vm)
        end
      end

      it "loads name-spaced model by fully-qualified name" do
        expect(miq_ae_service.service_model(:ManageIQ_Providers_Openstack_CloudManager)).to    be(
          MiqAeMethodService::MiqAeServiceManageIQ_Providers_Openstack_CloudManager)
        expect(miq_ae_service.service_model(:ManageIQ_Providers_Openstack_CloudManager_Vm)).to be(
          MiqAeMethodService::MiqAeServiceManageIQ_Providers_Openstack_CloudManager_Vm)
      end

      it "raises error on invalid service_model name" do
        expect { miq_ae_service.service_model(:invalid_model) }.to raise_error(NameError)
      end

      it "loads all mapped models" do
        MiqAeMethodService::MiqAeService::LEGACY_MODEL_NAMES.values.each do |model_name|
          expect { "MiqAeMethodService::MiqAeService#{model_name}".constantize }.to_not raise_error
        end
      end

      it "loads cloud networks" do
        items = %w(
          ManageIQ_Providers_Openstack_NetworkManager_CloudNetwork
          ManageIQ_Providers_Openstack_NetworkManager_CloudNetwork_Private
          ManageIQ_Providers_Openstack_NetworkManager_CloudNetwork_Public
        )
        items.each do |name|
          expect(miq_ae_service.vmdb(name)).to be("#{prefix}#{name}".constantize)
        end
      end
    end
  end

  describe MiqAeService do
    context "service models" do
      it "expose all expected active_record models as service_models" do
        excluded_model_names = %w(
          AuthToken
          AuthUseridPassword
          Category
          Datacenter
          ManageIQ::Providers::BaseManager
          ManageIQ::Providers::Kubernetes::ContainerManager::Scanning::Job
          VmServer
          VmSynchronize
        )

        base_models = MiqAeMethodService::MiqAeServiceModelBase.service_models
                                                               .collect(&:ar_base_model).uniq!

        # Determine descendants for all base_models of service models
        all_models = base_models.dup
        base_models.each { |bm| all_models += bm.descendants }
        all_models.uniq!
        all_models.delete_if { |klass| klass.name.nil? } # Ignore anonymous classes loaded from tests
        all_models.sort_by!(&:name)

        failed_models = []
        all_models.each do |ar_model|
          next if excluded_model_names.include?(ar_model.name)

          begin
            MiqAeMethodService::MiqAeServiceModelBase.model_name_from_active_record_model(ar_model).constantize
          rescue NameError
            failed_models << ar_model.name # Collect all failing model names
          end
        end

        expect(failed_models).to eq([])
      end
    end
  end

  describe MiqAeService do
    context "#prepend_namespace=" do
      let(:options) { {} }
      let(:workspace) { double("MiqAeEngine::MiqAeWorkspaceRuntime", :root => options) }
      let(:miq_ae_service) { MiqAeService.new(workspace) }
      let(:ns) { "fred" }

      it "set namespace" do
        allow(workspace).to receive(:persist_state_hash).and_return({})
        expect(workspace).to receive(:prepend_namespace=).with(ns)

        miq_ae_service.prepend_namespace = ns
      end
    end
  end
end

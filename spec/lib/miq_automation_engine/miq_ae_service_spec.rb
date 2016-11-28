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
      let(:workspace) { double('ws', :persist_state_hash => {}) }
      let(:miq_ae_service) { MiqAeService.new(workspace) }
      let(:prefix) { "MiqAeMethodService::MiqAeService" }

      it "loads base model" do
        allow(workspace).to receive(:disable_rbac)
        expect(miq_ae_service.service_model(:VmOrTemplate)).to   be(MiqAeMethodService::MiqAeServiceVmOrTemplate)
        expect(miq_ae_service.service_model(:vm_or_template)).to be(MiqAeMethodService::MiqAeServiceVmOrTemplate)
      end

      it "loads sub-classed model" do
        allow(workspace).to receive(:disable_rbac)
        expect(miq_ae_service.service_model(:Vm)).to be(MiqAeMethodService::MiqAeServiceVm)
        expect(miq_ae_service.service_model(:vm)).to be(MiqAeMethodService::MiqAeServiceVm)
      end

      it "loads model with mapped name" do
        allow(workspace).to receive(:disable_rbac)
        expect(miq_ae_service.service_model(:ems)).to be(MiqAeMethodService::MiqAeServiceExtManagementSystem)
      end

      it "loads name-spaced model by mapped name" do
        allow(workspace).to receive(:disable_rbac)
        MiqAeMethodService::Deprecation.silence do
          expect(miq_ae_service.service_model(:ems_openstack)).to be(
            MiqAeMethodService::MiqAeServiceManageIQ_Providers_Openstack_CloudManager)
          expect(miq_ae_service.service_model(:vm_openstack)).to  be(
            MiqAeMethodService::MiqAeServiceManageIQ_Providers_Openstack_CloudManager_Vm)
        end
      end

      it "loads name-spaced model by fully-qualified name" do
        allow(workspace).to receive(:disable_rbac)
        expect(miq_ae_service.service_model(:ManageIQ_Providers_Openstack_CloudManager)).to    be(
          MiqAeMethodService::MiqAeServiceManageIQ_Providers_Openstack_CloudManager)
        expect(miq_ae_service.service_model(:ManageIQ_Providers_Openstack_CloudManager_Vm)).to be(
          MiqAeMethodService::MiqAeServiceManageIQ_Providers_Openstack_CloudManager_Vm)
      end

      it "raises error on invalid service_model name" do
        allow(workspace).to receive(:disable_rbac)
        expect { miq_ae_service.service_model(:invalid_model) }.to raise_error(NameError)
      end

      it "loads all mapped models" do
        allow(workspace).to receive(:disable_rbac)
        MiqAeMethodService::MiqAeService::LEGACY_MODEL_NAMES.values.each do |model_name|
          expect { "MiqAeMethodService::MiqAeService#{model_name}".constantize }.to_not raise_error
        end
      end

      it "loads cloud networks" do
        allow(workspace).to receive(:disable_rbac)
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
          ManageIQ::Providers::PhysicalInfraManager
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
        allow(workspace).to receive(:disable_rbac)
        allow(workspace).to receive(:persist_state_hash).and_return({})
        expect(workspace).to receive(:prepend_namespace=).with(ns)

        miq_ae_service.prepend_namespace = ns
      end
    end
    context "create notifications" do
      before do
        NotificationType.seed
        allow(User).to receive_messages(:server_timezone => 'UTC')
        allow(workspace).to receive(:disable_rbac)
      end

      let(:options) { {} }
      let(:workspace) do
        double("MiqAeEngine::MiqAeWorkspaceRuntime", :root               => options,
                                                     :ae_user            => user,
                                                     :persist_state_hash => {})
      end
      let(:miq_ae_service) { MiqAeService.new(workspace) }
      let(:user) { FactoryGirl.create(:user_with_group) }
      let(:vm) { FactoryGirl.create(:vm) }
      let(:msg_text) { 'mary had a little lamb' }

      context "#create_notification!" do
        it "invalid type" do
          expect { miq_ae_service.create_notification!(:type => :invalid_type, :subject => vm) }
            .to raise_error(ArgumentError, "Invalid notification type specified")
        end

        it "invalid subject" do
          expect { miq_ae_service.create_notification!(:type => :vm_retired, :subject => 'fred') }
            .to raise_error(ArgumentError, "Subject must be a valid Active Record object")
        end

        it "default type of automate_user_info" do
          result = miq_ae_service.create_notification!(:message => msg_text)
          expect(result).to be_kind_of(MiqAeMethodService::MiqAeServiceNotification)
        end

        it "type of automate_user_info" do
          result = miq_ae_service.create_notification!(:level => 'success', :audience => 'user', :message => 'test')
          expect(result).to be_kind_of(MiqAeMethodService::MiqAeServiceNotification)
        end

        it "type of automate_tenant_info" do
          expect(user).to receive(:tenant).and_return(Tenant.root_tenant)
          result = miq_ae_service.create_notification!(:level => 'success', :audience => 'tenant', :message => 'test')
          expect(result).to be_kind_of(MiqAeMethodService::MiqAeServiceNotification)
        end

        it "type of automate_global_info" do
          result = miq_ae_service.create_notification!(:level => 'success', :audience => 'global', :message => 'test')
          expect(result).to be_kind_of(MiqAeMethodService::MiqAeServiceNotification)
        end
      end

      context "#create_notification" do
        it "invalid type" do
          expect { miq_ae_service.create_notification(:type => :invalid_type, :subject => vm) }
            .not_to raise_error
        end

        it "invalid subject" do
          expect { miq_ae_service.create_notification(:type => :vm_retired, :subject => 'fred') }
            .not_to raise_error
        end

        it "default type of automate_user_info" do
          result = miq_ae_service.create_notification(:message => msg_text)
          expect(result).to be_kind_of(MiqAeMethodService::MiqAeServiceNotification)
          ui_representation = result.object_send(:to_h)
          expect(ui_representation).to include(:text     => '%{message}',
                                               :bindings => a_hash_including(:message=>{:text=> msg_text}))
        end

        it "type of automate_user_info" do
          result = miq_ae_service.create_notification(:level => 'success', :audience => 'user', :message => 'test')
          expect(result).to be_kind_of(MiqAeMethodService::MiqAeServiceNotification)
        end

        it "type of automate_tenant_info" do
          expect(user).to receive(:tenant).and_return(Tenant.root_tenant)
          result = miq_ae_service.create_notification(:level => 'success', :audience => 'tenant', :message => 'test')
          expect(result).to be_kind_of(MiqAeMethodService::MiqAeServiceNotification)
        end

        it "type of automate_global_info" do
          result = miq_ae_service.create_notification(:level => 'success', :audience => 'global', :message => 'test')
          expect(result).to be_kind_of(MiqAeMethodService::MiqAeServiceNotification)
        end
      end
    end
  end
end

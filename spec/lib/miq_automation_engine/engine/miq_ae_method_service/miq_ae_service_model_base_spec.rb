describe MiqAeMethodService::MiqAeServiceModelBase do
  describe '.ar_model?' do
    it 'returns true for direct subclasses of ApplicationRecord' do
      expect(described_class.ar_model?(VmOrTemplate)).to be true
    end

    it 'returns true for grand-child subclasses of ApplicationRecord' do
      expect(described_class.ar_model?(Vm)).to be true
    end

    it 'returns false for classes not derived from ApplicationRecord' do
      expect(described_class.ar_model?(MiqRequestWorkflow)).to be false
    end

    it 'returns false for NilClass' do
      expect(described_class.ar_model?(nil)).to be false
    end
  end

  describe '.service_model_name_to_model' do
    it 'returns active record model for known class' do
      expect(described_class.service_model_name_to_model('MiqAeServiceVmOrTemplate')).to be VmOrTemplate
    end

    it 'returns nil for unknown class' do
      expect(described_class.service_model_name_to_model('MiqAeServiceVmOrNotVm')).to be_nil
    end
  end

  describe '.model_to_service_model_name' do
    it 'converts base model without namespaces' do
      expect(described_class.model_to_service_model_name(VmOrTemplate))
        .to eq 'MiqAeServiceVmOrTemplate'
    end

    it 'converts subclassed model with namespaces' do
      expect(described_class.model_to_service_model_name(ManageIQ::Providers::InfraManager::Vm))
        .to eq 'MiqAeServiceManageIQ_Providers_InfraManager_Vm'
    end
  end

  describe '.model_to_file_name' do
    it 'converts base model without namespaces' do
      expect(described_class.model_to_file_name(VmOrTemplate))
        .to eq 'miq_ae_service_vm_or_template.rb'
    end

    it 'converts subclassed model with namespaces' do
      expect(described_class.model_to_file_name(ManageIQ::Providers::InfraManager::Vm))
        .to eq 'miq_ae_service_manageiq-providers-infra_manager-vm.rb'
    end
  end

  describe '.model_to_file_path' do
    it 'converts base model without namespaces' do
      expect(described_class.model_to_file_path(VmOrTemplate))
        .to eq File.join(described_class::SERVICE_MODEL_PATH, 'miq_ae_service_vm_or_template.rb')
    end

    it 'converts subclassed model with namespaces' do
      expect(described_class.model_to_file_path(ManageIQ::Providers::InfraManager::Vm))
        .to eq File.join(described_class::SERVICE_MODEL_PATH, 'miq_ae_service_manageiq-providers-infra_manager-vm.rb')
    end
  end

  describe '.create_service_model_from_name' do
    it 'returns nil for names without miq_ae_service prefix' do
      expect(described_class.create_service_model_from_name(:VmOrTemplate)).to be_nil
    end

    context 'with a test class' do
      it 'return nil when not a subclass of ApplicationRecord' do
        expect(described_class.create_service_model_from_name(:MiqAeServiceMiqAeServiceModelSpec_TestInteger)).to be_nil
      end

      it 'returns a service_model class derived from MiqAeServiceModelBase' do
        test_class = described_class.create_service_model_from_name(:MiqAeServiceMiqAeServiceModelSpec_TestApplicationRecord)
        expect(test_class.name).to eq('MiqAeMethodService::MiqAeServiceMiqAeServiceModelSpec_TestApplicationRecord')
        expect(test_class.superclass.name).to eq('MiqAeMethodService::MiqAeServiceModelBase')
      end

      it 'returns a service_model class derived from MiqAeServiceVmOrTemplate' do
        test_class = described_class.create_service_model_from_name(:MiqAeServiceMiqAeServiceModelSpec_TestVmOrTemplate)
        expect(test_class.name).to eq('MiqAeMethodService::MiqAeServiceMiqAeServiceModelSpec_TestVmOrTemplate')
        expect(test_class.superclass.name).to eq('MiqAeMethodService::MiqAeServiceVmOrTemplate')
      end
    end
  end
end

module MiqAeServiceModelSpec
  class TestInteger < ::Integer; end
  class TestApplicationRecord < ::ApplicationRecord; end
  class TestVmOrTemplate < ::VmOrTemplate; end
end

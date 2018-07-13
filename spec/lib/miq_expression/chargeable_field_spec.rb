RSpec.describe MiqExpression::ChargeableField do
  describe '.parse' do
    it 'parses chargeable field with sub metric type' do
      field = 'ChargebackVm-storage_allocated_ceph-sas_cost'
      expect(described_class.parse(field)).to have_attributes(:model => ChargebackVm, :column => 'storage_allocated_ceph-sas_cost')
    end

    it 'parses chargeable field' do
      field = 'ChargebackVm-storage_allocated_cost'
      expect(described_class.parse(field)).to have_attributes(:model => ChargebackVm, :column => 'storage_allocated_cost')
      field = 'ChargebackContainerProject-storage_allocated_cost'
      expect(described_class.parse(field)).to have_attributes(:model => ChargebackContainerProject, :column => 'storage_allocated_cost')
    end

    it 'doesn\'t parse field model.belongs_to_associations with invalid format' do
      field = 'Vm.host'
      expect(described_class.parse(field)).to be_nil
    end

    it 'doesn\'t parse field with format of MiqExpression::Field::REGEX' do
      field = 'Vm.host-name'
      expect(described_class.parse(field)).to be_nil
    end

    it 'doesn\'t parse field with invalid format' do
      field = 'sdfsdf.host'
      expect(described_class.parse(field)).to be_nil
    end
  end
end

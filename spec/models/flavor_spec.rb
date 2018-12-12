describe Flavor do
  let(:ems) { FactoryBot.create(:ems_openstack) }

  context 'when calling raw_create_flavor methods' do
    it 'raises NotImplementedError' do
      expect do
        subject.class.raw_create_flavor(1, {})
      end.to raise_error(NotImplementedError, "raw_create_flavor must be implemented in a subclass")
    end
  end

  context 'when calling raw_create_flavor methods' do
    it 'raises NotImplementedError' do
      expect do
        subject.raw_delete_flavor
      end.to raise_error(NotImplementedError, "raw_delete_flavor must be implemented in a subclass")
    end
  end

  context 'when calling create_flavor method' do
    it 'should call raw_create_flavor' do
      flavor_double = class_double('ManageIQ::Providers::Openstack::CloudManager::Flavor')
      allow(subject.class).to receive(:class_by_ems).and_return(flavor_double)
      expect(flavor_double).to receive(:raw_create_flavor)
      subject.class.create_flavor(ems.id, {})
    end
  end

  context 'when calling delete_flavor method' do
    it 'should call raw_delete_flavor' do
      expect(subject).to receive(:raw_delete_flavor)
      subject.delete_flavor
    end
  end
end

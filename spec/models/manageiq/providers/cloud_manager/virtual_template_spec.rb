describe ManageIQ::Providers::CloudManager::VirtualTemplate do
  let(:vt_properties) do
    {
      vendor: 'amazon',
      name: 'virtualtemplate',
      location: 'here',
      ems_ref: 'i-12345',
      availability_zone_id: 1,
      cloud_network_id: 1,
      cloud_subnet_id: 1
    }
  end

  describe '#name' do
    it 'is required' do
      expect { FactoryGirl.create(:virtual_template, vt_properties.except(:name)) }
          .to raise_error(ActiveRecord::RecordInvalid, /Name can't be blank/)
    end
  end

  describe '#ems_ref' do
    it 'is required' do
      expect { FactoryGirl.create(:virtual_template, vt_properties.except(:ems_ref)) }
          .to raise_error(ActiveRecord::RecordInvalid, /Ems ref can't be blank/)
    end
  end

  describe '#cloud_network_id' do
    it 'is required' do
      expect { FactoryGirl.create(:virtual_template, vt_properties.except(:cloud_network_id)) }
          .to raise_error(ActiveRecord::RecordInvalid, /Cloud network can't be blank/)
    end
  end
end
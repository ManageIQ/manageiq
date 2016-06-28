describe ManageIQ::Providers::CloudManager::VirtualTemplate do
  let(:vt_properties) do
    {
      :vendor   => 'amazon',
      :name     => 'virtualtemplate',
      :location => 'here',
    }
  end

  describe '#type' do
    it 'may only have one per type' do
      FactoryGirl.create(:virtual_template, vt_properties)
      expect { FactoryGirl.create(:virtual_template, vt_properties) }
        .to raise_error(ActiveRecord::RecordInvalid, /Virtual template may only have one per type/)
    end
  end

  describe '#cloud' do
    it 'has a default value of true' do
      vt = FactoryGirl.create(:virtual_template, vt_properties)

      expect(vt.cloud).to be_truthy
    end
  end
end

describe ArbitrationDefault do
  describe '#ems_id' do
    let(:ems) { FactoryGirl.create(:external_management_system) }

    it 'validates external management system' do
      expect { FactoryGirl.create(:arbitration_default) }
        .to raise_error(ActiveRecord::RecordInvalid, /Ext management system can't be blank/)
    end
  end
end

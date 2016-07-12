describe ArbitrationDefault do
  describe '#ems_id' do
    let(:ems) { FactoryGirl.create(:ext_management_system) }

    it 'validates existence of external management system' do
      expect { FactoryGirl.create(:arbitration_default) }
        .to raise_error(ActiveRecord::RecordInvalid, /Ext management system can't be blank/)
    end

    it 'validates uniqueness of external management system' do
      FactoryGirl.create(:arbitration_default, :ems_id => ems.id)

      expect { FactoryGirl.create(:arbitration_default, :ems_id => ems.id) }
        .to raise_error(ActiveRecord::RecordInvalid, /Ext management system has already been taken/)
    end
  end
end

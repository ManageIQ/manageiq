describe ArbitrationProfile do
  let(:ems) { FactoryGirl.create(:ext_management_system) }

  describe '#ems_id' do
    it 'validates existence of ext management system' do
      expect { FactoryGirl.create(:arbitration_profile) }
        .to raise_error(ActiveRecord::RecordInvalid, /Ext management system can't be blank/)
    end
  end

  describe '#name' do
    it 'requires a name' do
      expect { FactoryGirl.create(:arbitration_profile, :ems_id => ems.id, :name => nil) }
        .to raise_error(ActiveRecord::RecordInvalid, /Name can't be blank/)
    end
  end

  describe '#default_profile' do
    it 'will falsify all other records when new default is set' do
      original_default = FactoryGirl.create(:arbitration_profile, :default, :ems_id => ems.id)
      original_non_default = FactoryGirl.create(:arbitration_profile, :ems_id => ems.id)

      expect(original_default.default_profile).to be_truthy
      expect(original_non_default.default_profile).to be_falsey
      expect(ArbitrationProfile.where(:default_profile => true).count).to eq(1)

      original_non_default.update_attributes(:default_profile => true)

      expect(original_default.reload.default_profile).to be_falsey
      expect(original_non_default.reload.default_profile).to be_truthy
      expect(ArbitrationProfile.where(:default_profile => true).count).to eq(1)
    end

    it 'will falsify all other records when new default is created' do
      original_default = FactoryGirl.create(:arbitration_profile, :default, :ems_id => ems.id)

      expect(original_default.default_profile).to be_truthy

      new_default = FactoryGirl.create(:arbitration_profile, :default, :ems_id => ems.id)

      expect(original_default.reload.default_profile).to be_falsey
      expect(new_default.default_profile).to be_truthy
    end
  end
end

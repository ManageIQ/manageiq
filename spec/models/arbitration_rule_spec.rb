describe ArbitrationRule do
  describe '#condition' do
    it 'validates allowed conditions' do
      expect { FactoryGirl.create(:arbitration_rule, :condition => 'greater than') }
        .to raise_error(ActiveRecord::RecordInvalid, /Condition is not included in the list/)
    end
  end

  describe '#action' do
    it 'validates allowed actions' do
      expect { FactoryGirl.create(:arbitration_rule, :action => 'skip') }
        .to raise_error(ActiveRecord::RecordInvalid, /Action is not included in the list/)
    end
  end

  describe '#object_attribute' do
    it 'requires a parameter' do
      expect { FactoryGirl.create(:arbitration_rule) }
        .to raise_error(ActiveRecord::RecordInvalid, /Object attribute can't be blank/)
    end
  end

  describe '#object_attribute_value' do
    it 'requires a value' do
      expect { FactoryGirl.create(:arbitration_rule) }
        .to raise_error(ActiveRecord::RecordInvalid, /Object attribute value can't be blank/)
    end
  end
end

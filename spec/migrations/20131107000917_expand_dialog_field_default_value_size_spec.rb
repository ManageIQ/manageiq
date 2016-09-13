require_migration

describe ExpandDialogFieldDefaultValueSize do
  let(:dialog_field_stub) { migration_stub(:DialogField) }
  let(:reserve_stub)      { Spec::Support::MigrationStubs.reserved_stub }

  migration_context :up do
    it "should convert default_value to text type" do
      expect(dialog_field_stub.columns_hash['default_value'].type).to eq(:string)
      migrate
      expect(dialog_field_stub.columns_hash['default_value'].type).to eq(:text)
    end

    it "should migrate default_value from the reserved table" do
      val1      = "default value 1"
      field1    = dialog_field_stub.create!
      reserved1 = reserve_stub.create!(:resource_id   => field1.id,
                                       :resource_type => 'DialogField',
                                       :reserved      => {:default_value => val1})
      val2      = "default value 2"
      field2    = dialog_field_stub.create!(:default_value => val2)
      reserved2 = reserve_stub.create!(:resource_id   => field2.id,
                                       :resource_type => 'DialogField',
                                       :reserved      => {:some_field => 1})
      val3   = "default value 3"
      field3 = dialog_field_stub.create!(:default_value => val3)

      migrate

      expect { reserved1.reload }.to raise_error(ActiveRecord::RecordNotFound)
      expect { reserved2.reload }.to_not raise_error
      expect(field1.reload.default_value).to eq(val1)
      expect(field2.reload.default_value).to eq(val2)
      expect(field3.reload.default_value).to eq(val3)
    end
  end

  migration_context :down do
    it "should convert default_value to string type" do
      expect(dialog_field_stub.columns_hash['default_value'].type).to eq(:text)
      migrate
      expect(dialog_field_stub.columns_hash['default_value'].type).to eq(:string)
    end

    it "should migrate default_value to the reserved table" do
      val1   = "default value 1"
      field1 = dialog_field_stub.create!(:default_value => val1)
      field2 = dialog_field_stub.create!

      migrate

      reserve1 = reserve_stub.where(:resource_id   => field1.id,
                                    :resource_type => 'DialogField').first!
      expect(reserve1.reserved).to eq(:default_value => val1)
      expect(reserve_stub.where(:resource_id   => field2.id,
                                :resource_type => 'DialogField')).not_to exist
    end
  end
end

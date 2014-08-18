require "spec_helper"
require Rails.root.join("db/migrate/20131107000917_expand_dialog_field_default_value_size.rb")

describe ExpandDialogFieldDefaultValueSize do
  migration_context :up do
    let(:reserve_stub) { migration_stub(:Reserve) }
    let(:dialog_field_stub) { migration_stub(:DialogField) }

    it "should convert default_value to text type" do
      dialog_field_stub.columns_hash['default_value'].type.should == :string
      migrate
      dialog_field_stub.columns_hash['default_value'].type.should == :text
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
      field1.reload.default_value.should == val1
      field2.reload.default_value.should == val2
      field3.reload.default_value.should == val3
    end

  end

  migration_context :down do
    let(:reserve_stub) { migration_stub(:Reserve) }
    let(:dialog_field_stub) { migration_stub(:DialogField) }

    it "should convert default_value to string type" do
      dialog_field_stub.columns_hash['default_value'].type.should == :text
      migrate
      dialog_field_stub.columns_hash['default_value'].type.should == :string
    end

    it "should migrate default_value to the reserved table" do
      val1   = "default value 1"
      field1 = dialog_field_stub.create!(:default_value => val1)
      field2 = dialog_field_stub.create!

      migrate

      reserve1 = reserve_stub.where(resource_id: field1.id,
                                    resource_type: 'DialogField').first!
      reserve1.reserved.should == {:default_value => val1}
      reserve_stub.where(resource_id: field2.id, 
                         resource_type: 'DialogField').should_not exist
    end
  end
end

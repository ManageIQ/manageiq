RSpec.describe ApplicationRecord do
  context ".human_attribute_name includes the class name in the validation error for easier troubleshooting" do
    it "single level" do
      Zone.create!(:name => "example", :description => "example")
      expect { Zone.create!(:name => "example", :description => "example") }.to raise_error(ActiveRecord::RecordInvalid, "Validation failed: Zone: Name is not unique within region #{MiqRegion.my_region_number}")
    end

    it "nested" do
      Zone.create!(:name => "example", :description => "example")
      expect { MiqSchedule.create!(:zone => Zone.create!(:name => "example", :description => "example")) }.to raise_error(ActiveRecord::RecordInvalid, "Validation failed: Zone: Name is not unique within region #{MiqRegion.my_region_number}")
    end
  end
end

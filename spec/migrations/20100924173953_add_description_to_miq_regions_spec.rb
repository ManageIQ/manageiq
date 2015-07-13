require "spec_helper"
require Rails.root.join("db/migrate/20100924173953_add_description_to_miq_regions.rb")

describe AddDescriptionToMiqRegions do
  migration_context :up do
    let(:miq_region_stub)  { migration_stub(:MiqRegion) }

    it "adds description column and sets value from region column" do
      region = miq_region_stub.create!(:region => 1)

      migrate

      region.reload.description.should == "Region #{region.region}"
    end
  end
end

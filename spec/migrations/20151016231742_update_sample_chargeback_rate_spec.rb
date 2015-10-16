require "spec_helper"
require_migration

describe UpdateSampleChargebackRate do

  migration_context :up do
    describe "for default Chargeback Rates" do
      it "update description to 'Sample'" do
        compute_rate = UpdateSampleChargebackRate::ChargebackRate.create!(:description => "Bazzillion", :rate_type => "Compute", :default => true)
        storage_rate = UpdateSampleChargebackRate::ChargebackRate.create!(:description => "Bazzillion", :rate_type => "Storage", :default => true)

        migrate

        expect(compute_rate.reload).to have_attributes(:description => 'Sample')
        expect(storage_rate.reload).to have_attributes(:description => 'Sample')
      end
    end
  end
end

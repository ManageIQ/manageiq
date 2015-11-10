require "spec_helper"
require_migration

describe ChargebackRateDetailCurrencyNotNil do
  migration_context :up do
    before(:each) do
      @cbd = FactoryGirl.create(:chargeback_rate_detail,
                                :rate     => 8,
                                :per_time => "hourly",
                                :per_unit => "megabytes",
                                :metric   => 'derived_memory_available',
                               )
    end

    it "change to default currency" do
      currency = ChargebackRateDetailCurrency.first.id
      @cbd.update_attribute(:chargeback_rate_detail_currency_id, currency)
      migrate

      expect(@cbd.reload.chargeback_rate_detail_currency_id).to eq(currency)
    end

    it "doesnt changes nil" do
      @cbd.update_attribute(:chargeback_rate_detail_currency_id, 5)
      migrate

      expect(@cbd.reload.chargeback_rate_detail_currency_id).to eq(5)
    end
  end
end

require "spec_helper"
require_migration

describe ChargebackRateDetailCurrencyNotNil do
  let(:chargeback_rate_detail_stub) { migration_stub(:ChargebackRateDetail) }

  migration_context :up do
    it "change to false" do
      #if the chargeback_rate_detail don't have any currency, chargeback_rate_detail_currency_id will be false
      #currency = chargeback_rate_detail_currency_stub.first.id
      chargeback_rate_detail = chargeback_rate_detail_stub.create(:chargeback_rate_detail_currency_id => 0)
      migrate

      expect(chargeback_rate_detail.reload.chargeback_rate_detail_currency_id).to eq(0)
    end

    it "doesnt changes nil" do
      #if the chargeback_rate_detail have a currency, a possible chargeback_rate_detail_currency_id would be 5
      chargeback_rate_detail = chargeback_rate_detail_stub.create(:chargeback_rate_detail_currency_id => 5)
      migrate

      expect(chargeback_rate_detail.reload.chargeback_rate_detail_currency_id).to eq(5)
    end
  end
end

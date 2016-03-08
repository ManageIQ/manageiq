require "spec_helper"
require_migration

describe ChargebackRateDetailCurrencyNotNil do
  let(:chargeback_rate_detail_stub) { migration_stub(:ChargebackRateDetail) }
  let(:chargeback_rate_detail_currency_stub) { migration_stub(:ChargebackRateDetailCurrency) }

  migration_context :up do
    it "changes existing rate detail without currency to the default currency" do
      chargeback_rate_detail = chargeback_rate_detail_stub.create(:chargeback_rate_detail_currency_id => nil)
      migrate

      expect(chargeback_rate_detail.reload.chargeback_rate_detail_currency_id).not_to be_nil
    end

    it "doesn't change the chargeback_rate_detail if it has already a currency" do
      chargeback_rate_detail = chargeback_rate_detail_stub.create(:chargeback_rate_detail_currency_id => 5)
      migrate

      expect(chargeback_rate_detail.reload.chargeback_rate_detail_currency_id).to eq(5)
    end

    it "does nothing if no chargeback_rate_details exist" do
      migrate

      expect(chargeback_rate_detail_currency_stub.count).to eq(0)
    end
  end
end

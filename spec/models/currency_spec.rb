RSpec.describe Currency do
  describe '.seed' do
    it "returns supported currencies" do
      Currency.seed

      expected_currencies = %w[AED AFN ALL AMD ANG AOA ARS AUD AWG AZN BAM BBD BDT BGN BHD BIF BMD BND BOB BRL BSD BTN BWP BYN BYR BZD CAD CDF CHF CLF CLP CNY COP CRC CUC CUP CVE CZK DJF DKK DOP DZD EGP ERN ETB EUR FJD FKP GBP GEL GHS GIP GMD GNF GTQ GYD HKD HNL HRK HTG HUF IDR ILS INR IQD IRR ISK JMD JOD JPY KES KGS KHR KMF KPW KRW KWD KYD KZT LAK LBP LKR LRD LSL LYD MAD MDL MGA MKD MMK MNT MOP MRU MUR MVR MWK MXN MYR MZN NAD NGN NIO NOK NPR NZD OMR PAB PEN PGK PHP PKR PLN PYG QAR RON RSD RUB RWF SAR SBD SCR SDG SEK SGD SHP SKK SLL SOS SRD SSP STD SVC SYP SZL THB TJS TMT TND TOP TRY TTD TWD TZS UAH UGX USD UYU UZS VES VND VUV WST XAF XAG XAU XCD XDR XOF XPD XPF XPT YER ZAR ZMK ZMW]
      expect(Currency.all.map(&:code)).to match_array(expected_currencies)
    end
  end

  it "has a valid factory" do
    expect(FactoryBot.create(:currency)).to be_valid
  end

  it "is invalid without a code" do
    expect(FactoryBot.build(:currency, :code => nil)).not_to be_valid
  end

  it "is invalid without a name" do
    expect(FactoryBot.build(:currency, :name => nil)).not_to be_valid
  end

  it "is invalid without a full_name" do
    expect(FactoryBot.build(:currency, :full_name => nil)).not_to be_valid
  end

  it "is invalid without a symbol" do
    expect(FactoryBot.build(:currency, :symbol => nil)).not_to be_valid
  end
end

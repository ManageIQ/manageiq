require 'rails_helper'

RSpec.describe ShowbackTariff, :type => :model do
  let(:tariff) { FactoryGirl.build(:showback_tariff) }

  it 'has a valid factory' do
    tariff.valid?
    expect(tariff).to be_valid
  end

  it 'is not valid without a name' do
    tariff.name = nil
    tariff.valid?
    expect(tariff.errors[:name]).to include("can't be blank")
    expect(tariff.errors.details[:name]). to include(:error => :blank)
  end

  it 'is not valid without a description' do
    tariff.description = nil
    tariff.valid?
    expect(tariff.errors.details[:description]). to include(:error => :blank)
  end

  it 'is not valid without an association to a parent element' do
    tariff.resource = nil
    tariff.valid?
    expect(tariff.errors.details[:resource]). to include(:error => :blank)
  end

  it 'is possible to add new rates to the tariff' do
    tariff.save
    rate = FactoryGirl.build(:showback_rate, :showback_tariff => tariff)
    expect { rate.save }.to change(tariff.showback_rates, :count).from(0).to(1)
  end
  it 'rates are deleted when deleting the tariff' do
    FactoryGirl.create(:showback_rate, :showback_tariff => tariff)
    FactoryGirl.create(:showback_rate, :showback_tariff => tariff)
    expect(tariff.showback_rates.count).to be(2)
    expect { tariff.destroy }.to change(ShowbackRate, :count).from(2).to(0)
  end

  context ".seed" do
    before(:all) do
      @expected_showback_tariff_count = 1
      FactoryGirl.create(:miq_enterprise, :name => 'Enterprise')
    end

    it "empty table" do
      ShowbackTariff.seed
      expect(ShowbackTariff.count).to eq(@expected_showback_tariff_count)
    end

    it "run twice" do
      ShowbackTariff.seed
      ShowbackTariff.seed
      expect(ShowbackTariff.count).to eq(@expected_showback_tariff_count)
    end
  end
end

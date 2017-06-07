require 'rails_helper'

RSpec.describe ShowbackPricePlan, :type => :model do
  let(:plan) { FactoryGirl.build(:showback_price_plan) }

  it 'has a valid factory' do
    plan.valid?
    expect(plan).to be_valid
  end

  it 'is not valid without a name' do
    plan.name = nil
    plan.valid?
    expect(plan.errors[:name]).to include("can't be blank")
    expect(plan.errors.details[:name]). to include(:error => :blank)
  end

  it 'is not valid without a description' do
    plan.description = nil
    plan.valid?
    expect(plan.errors.details[:description]). to include(:error => :blank)
  end

  it 'is not valid without an association to a parent element' do
    plan.resource = nil
    plan.valid?
    expect(plan.errors.details[:resource]). to include(:error => :blank)
  end

  it 'is possible to add new rates to the price plan' do
    plan.save
    rate = FactoryGirl.build(:showback_rate, :showback_price_plan => plan)
    expect { rate.save }.to change(plan.showback_rates, :count).from(0).to(1)
  end

  it 'rates are deleted when deleting the plan' do
    FactoryGirl.create(:showback_rate, :showback_price_plan => plan)
    FactoryGirl.create(:showback_rate, :showback_price_plan => plan)
    expect(plan.showback_rates.count).to be(2)
    expect { plan.destroy }.to change(ShowbackRate, :count).from(2).to(0)
  end

  context ".seed" do
    before(:all) do
      @expected_showback_price_plan_count = 1
      FactoryGirl.create(:miq_enterprise, :name => 'Enterprise')
    end

    it "empty table" do
      ShowbackPricePlan.seed
      expect(ShowbackPricePlan.count).to eq(@expected_showback_price_plan_count)
    end

    it "run twice" do
      ShowbackPricePlan.seed
      ShowbackPricePlan.seed
      expect(ShowbackPricePlan.count).to eq(@expected_showback_price_plan_count)
    end
  end
end

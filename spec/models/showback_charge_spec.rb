require 'rails_helper'

RSpec.describe ShowbackCharge, type: :model do
  let(:charge) { FactoryGirl.build(:showback_charge) }

  it 'has a valid factory' do
    expect(charge).to be_valid
  end

  it 'is not valid without a bucket' do
    charge.showback_bucket=nil
    charge.valid?
    expect(charge.errors.details[:showback_bucket]). to include({:error => :blank})
  end

  it 'is not valid without an event' do
    charge.showback_event = nil
    charge.valid?
    expect(charge.errors.details[:showback_event]). to include({:error => :blank})
  end

  it 'is valid with nil fixed_cost' do
    charge.fixed_cost = nil
    charge.valid?
    expect(charge).to be_valid
  end

  it 'is valid with nil variable_cost' do
    charge.variable_cost = nil
    charge.valid?
    expect(charge).to be_valid
  end

  it 'is valid when assigning fixed_costs' do
    charge.fixed_cost = 15
    charge.valid?
    expect(charge).to be_valid
  end

  pending 'is not valid if fixed cost is not money'
  pending 'is not valid if variable cost is not money'
end

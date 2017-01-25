require 'rails_helper'

RSpec.describe ChargeableField, :type => :model do
  describe '#rate_name' do
    let(:source) { 'used' }
    let(:group) { 'cpu' }
    let(:field) { FactoryGirl.build(:chargeable_field, :source => source, :group => group) }
    subject { field.send :rate_name }
    it { is_expected.to eq("#{group}_#{source}") }
  end
end

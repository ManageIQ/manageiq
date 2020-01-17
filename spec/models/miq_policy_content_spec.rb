RSpec.describe MiqPolicyContent do
  context 'Empty content' do
    describe '#export_to_array' do
      subject { FactoryBot.create(:miq_policy_content).export_to_array }
      it { is_expected.to match_array(['MiqPolicyContent'=>{}]) }
    end
  end
end

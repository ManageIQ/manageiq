RSpec.describe SecurityPolicy do
  include Spec::Support::ArelHelper

  let(:policy) { FactoryBot.create(:security_policy) }
  let!(:rules) { FactoryBot.create_list(:security_policy_rule, 2, :security_policy => policy) }

  describe "#rules" do
    it "matches security_policy_rules" do
      expect(policy.rules.order(:id)).to eq(rules)
    end
  end

  # subject setup for virtual attributes
  subject { policy }
  it_behaves_like "sql friendly virtual_attribute", :rules_count, 2
end

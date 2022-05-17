RSpec.describe SecurityPolicy do
  include Spec::Support::ArelHelper

  let(:policy) { FactoryBot.create(:security_policy) }

  let(:rules) { FactoryBot.create_list(:security_policy_rule, 2, :security_policy => policy) }

  describe "#rules" do
    it "matches security_policy_rules" do
      rules

      expect(policy.rules.order(:id)).to eq(rules)
    end
  end

  describe "#rules_count" do
    it "calculates in ruby" do
      rules
      expect(policy.rules_count).to eq(2)
    end

    it "calculates in the database" do
      rules
      expect(virtual_column_sql_value(SecurityPolicy, "rules_count")).to eq(2)
    end
  end
end

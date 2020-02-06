RSpec.describe Entitlement do
  describe "validation" do
    it "can have a managed filter if it doesn't have a filter expression" do
      entitlement = FactoryBot.build(:entitlement)
      entitlement.set_managed_filters([["/managed/environment/test"]])
      expect(entitlement).to be_valid
    end

    it "can have a filter expression if it doesn't have a managed filter" do
      entitlement = FactoryBot.build(:entitlement)
      expression = MiqExpression.new("=" => {"tag" => "managed-environment", "value" => "test"})
      entitlement.filter_expression = expression
      expect(entitlement).to be_valid
    end

    it "cannot have both managed filters and a filter expression" do
      entitlement = FactoryBot.build(:entitlement)
      expression = MiqExpression.new("=" => {"tag" => "managed-environment", "value" => "test"})
      entitlement.filter_expression = expression
      entitlement.set_managed_filters([["/managed/environment/test"]])
      expect(entitlement).not_to be_valid
    end

    it "can have a filter expression and a belongs_to filter" do
      entitlement = FactoryBot.build(:entitlement)
      expression = MiqExpression.new("=" => {"tag" => "managed-environment", "value" => "test"})
      entitlement.filter_expression = expression
      entitlement.set_belongsto_filters([["/belongsto/ExtManagementSystem/ems1"]])
      expect(entitlement).to be_valid
    end
  end

  describe "::remove_tag_from_all_managed_filters" do
    let!(:entitlement1) { FactoryBot.create(:entitlement) }
    let!(:entitlement2) { FactoryBot.create(:entitlement) }

    before do
      entitlement1.set_managed_filters([["/managed/prov_max_memory/test", "/managed/prov_max_memory/1024"],
                                        ["/managed/my_name/test"]])
      entitlement2.set_managed_filters([["/managed/prov_max_memory/1024"]])
      [entitlement1, entitlement2].each(&:save)
    end

    it "removes managed filter from all groups" do
      described_class.remove_tag_from_all_managed_filters("/managed/prov_max_memory/1024")

      expect(entitlement1.reload.get_managed_filters).to match_array([["/managed/prov_max_memory/test"],
                                                                      ["/managed/my_name/test"]])
      expect(entitlement2.reload.get_managed_filters).to be_empty
    end
  end
end

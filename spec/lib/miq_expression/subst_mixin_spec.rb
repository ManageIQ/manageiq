RSpec.describe MiqExpression::SubstMixin do
  let(:test_class) { Class.new { include MiqExpression::SubstMixin } }
  let(:test_obj) { test_class.new }

  describe "#exp_replace_qs_tokens" do
    it "removes :token key from passed expression" do
      exp = {"and" => [{"=" => {"field" => "Vm-active", "value" => "true"}, :token => 1}, {"=" => {"field" => "Vm-archived", "value" => "true"}, :token => 2}]}
      test_obj.exp_replace_qs_tokens(exp, {})
      expect(exp).to eq("and" => [{"=" => {"field" => "Vm-active", "value" => "true"}}, {"=" => {"field" => "Vm-archived", "value" => "true"}}])
    end
  end

  describe "#exp_find_by_token" do
    it "returns correct expression when expression has mixed operators" do
      exp =
        {
          "and" =>
            [
              {"=" => {"field" => "ManageIQ::Providers::InfraManager::Vm-active", "value" => "true"}, :token => 1},
              {"or" =>
                [
                  {"=" => {"count" => "ManageIQ::Providers::InfraManager::Vm.advanced_settings", "value" => "1"}, :token => 2},
                  {"=" => {"count" => "ManageIQ::Providers::InfraManager::Vm.storages", "value" => "1"}, :token => 3}
                ]
              }
            ]
        }
      result = test_obj.exp_find_by_token(exp, 2)
      expect(result).to eq("=" => {"count" => "ManageIQ::Providers::InfraManager::Vm.advanced_settings", "value" => "1"}, :token => 2)
    end

    it "returns correct expression when expressions is simple has single operator" do
      exp =
        {
          "and" =>
            [
              {"=" => {"field" => "ManageIQ::Providers::InfraManager::Vm-active", "value" => "true"}, :token => 1},
              {"CONTAINS" => {"tag" => "ManageIQ::Providers::InfraManager::Vm.managed-prov_max_cpu", "value" => "2"}, :token => 2},
              {"CONTAINS" => {"tag" => "ManageIQ::Providers::InfraManager::Vm.managed-prov_max_retirement_days", "value" => "60"}, :token => 3}
            ]
        }
      result = test_obj.exp_find_by_token(exp, 3)
      expect(result).to eq("CONTAINS" => {"tag" => "ManageIQ::Providers::InfraManager::Vm.managed-prov_max_retirement_days", "value" => "60"}, :token => 3)
    end
  end
end

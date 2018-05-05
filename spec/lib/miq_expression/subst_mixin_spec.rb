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
end

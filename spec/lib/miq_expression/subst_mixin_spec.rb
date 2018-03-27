RSpec.describe MiqExpression::SubstMixin do
  let(:test_class) { Class.new { include MiqExpression::SubstMixin } }
  let(:test_obj) { test_class.new }

  describe "#exp_replace_qs_tokens" do
    it "removes :token key from passed expression" do
      exp = {"=" => {"field" => "Vm-active", "value" => "true"}, :token => 1}
      test_obj.exp_replace_qs_tokens(exp, {})
      expect(exp).to eq("=" => {"field" => "Vm-active", "value" => "true"})
    end
  end
end

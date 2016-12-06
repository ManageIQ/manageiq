describe ApplicationController, "::Filter" do
  before :each do
    controller.instance_variable_set(:@sb, {})
  end

  describe "#load_default_search" do
    it "calls load_default_search when filter is ALL(id=0)" do
      expect(controller).to receive(:clear_default_search)
      expect do
        controller.load_default_search(0) # id = 0
      end.not_to raise_error
    end
  end

  context "Verify removal of tokens from expressions" do
    it "removes tokens if present" do
      e = MiqExpression.new({"=" => {:field => "Vm.name", :value => "Test"}, :token => 1})
      exp = e.exp
      controller.send(:exp_remove_tokens, exp)
      expect(exp.inspect.include?(":token")).to be_falsey
    end

    it "removes tokens if present in complex expression" do
      e = MiqExpression.new("or" => [{"=" => {:field => "Vm.name", :value => "Test"}, :token => 1},
                                     {"=" => {:field => "Vm.name", :value => "Test2"}, :token => 2}])
      exp = e.exp
      controller.send(:exp_remove_tokens, exp)
      expect(exp.inspect.include?(":token")).to be_falsey
    end

    it "leaves expression untouched if no tokens present" do
      e = MiqExpression.new("=" => {:field => "Vm.name", :value => "Test"})
      exp = e.exp
      exp2 = copy_hash(exp)
      controller.send(:exp_remove_tokens, exp2)
      expect(exp.inspect).to eq(exp2.inspect)
    end

    let(:expression) do
      ApplicationController::Filter::Expression.new.tap do |e|
        e.val1 = {}
        e.val2 = {}
        e.expression = {}
      end
    end

    it "removes tokens if present" do
      exp = {'???' => '???'}
      edit = {:expression => expression, :edit_exp => exp}
      edit[:new] = {:expression => {:test => "foo", :token => 1}}
      session[:edit] = edit
      controller.instance_variable_set(:@_params, :pressed => "discard")
      controller.instance_variable_set(:@expkey, :expression)
      expect(controller).to receive(:render)
      controller.send(:exp_button)
      expect(session[:edit][:expression].val1).to be_nil
      expect(session[:edit][:expression].val2).to be_nil
      expect(session[:edit]).not_to include(:edit_exp)
      expect(session[:edit][:expression].expression).to eq(edit[:new][:expression])
    end
  end

  describe "#save_default_search" do
    let(:user) { FactoryGirl.create(:user_with_group, :settings => {:default_search => {}}) }
    it "saves settings" do
      search = FactoryGirl.create(:miq_search, :name => 'sds')

      login_as user
      controller.instance_variable_set(:@settings, {})
      controller.instance_variable_set(:@_response, double.as_null_object)
      controller.instance_variable_set(:@_params, :id => search.id)
      session[:view] = controller.send(:get_db_view, Host)

      controller.send(:save_default_search)
      user.reload

      expect(user.settings).to eq(:default_search => {:Host => search.id})
    end
  end
end

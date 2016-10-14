describe ApplicationHelper::Button::Condition do
  describe "#role_allows_feature?" do
    let(:session) { Hash.new }
    before do
      sandbox = {:active_tree => :condition_tree}
      @view_context = setup_view_context_with_sandbox(sandbox)
      @button = described_class.new(@view_context, {}, {}, :child_id => "condition_copy")
    end

    it "will be skipped" do
      expect(@button.role_allows_feature?).to be false
    end

    it "won't be skipped", :type => :helper do
      login_as FactoryGirl.create(:user, :features => "condition_copy")
      expect(@button.role_allows_feature?).to be true
    end
  end

  describe "#disabled?" do
    before do
      @condition = FactoryGirl.create(:condition)
      sandbox = {:active_tree => :condition_tree}
      @view_context = setup_view_context_with_sandbox(sandbox)
      @button = described_class.new(@view_context, {}, {'condition' => @condition}, :child_id => "condition_delete")
    end

    it "will be disabled" do
      allow(@condition).to receive(:miq_policies).and_return(['a'])
      expect(@button.disabled?).to be true
    end

    it "won't be disabled" do
      expect(@button.disabled?).to be false
    end
  end
end

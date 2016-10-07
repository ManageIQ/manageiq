describe ApplicationHelper::Button::PolicyCopy do
  describe '#visible?' do

    let(:button) do
      described_class.new(
        view_context,
        {},
        {'record' => @record},
        {:options   => {:feature => 'policy_copy'}}
      )
    end

    let(:view_context) { setup_view_context_with_sandbox({}) }

    before do
      @record = FactoryGirl.create(:miq_policy)
    end

    it "that supports policy_copy will not be skipped" do
      allow(button).to receive(:role_allows_feature?).and_return(true)
      allow(view_context).to receive(:x_active_tree).and_return(:policy_tree)

      expect(button.skipped?).to be_falsey
    end

    it "that dont support feature :some_feature will be skipped" do
      allow(button).to receive(:role_allows_feature?).and_return(false)
      expect(button.skipped?).to be_truthy
    end
  end
end

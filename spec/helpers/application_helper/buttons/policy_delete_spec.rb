describe ApplicationHelper::Button::PolicyDelete do
  describe '#skip?' do
    it "that supports policy_copy will not be skipped" do
      view_context = setup_view_context_with_sandbox({})
      allow(view_context).to receive(:role_allows?).and_return(true)
      button = described_class.new(
        view_context,
        {},
        {},
        {:options   => {:feature => 'policy_delete', :condition => proc { false }}}
      )
      expect(button.skip?).to be_falsey
    end

    it "that dont support feature :some_feature will be skipped" do
      view_context = setup_view_context_with_sandbox({})
      allow(view_context).to receive(:role_allows?).and_return(false)
      button = described_class.new(
        view_context,
        {},
        {},
        {:options   => {:feature => 'policy_delete', :condition => proc { false }}}
      )
      expect(button.skip?).to be_truthy
    end
  end
end

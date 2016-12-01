describe ApplicationHelper::Button::BasicImage do
  describe '#visible?' do
    before do
      @view_context = setup_view_context_with_sandbox({:trees => {:vandt_tree => {:active_node => "xx-arch"}},
                                                       :active_tree => :vandt_tree})
    end
    context "in list of archived VMs" do
      it "will be skipped" do
        button = described_class.new(@view_context, {}, {}, {})
        expect(button.visible?).to be_falsey
      end
    end

    context "in list of orphaned VMs" do
      it "will be skipped" do
        @view_context.x_node = "xx-orph"
        button = described_class.new(@view_context, {}, {}, {})
        expect(button.visible?).to be_falsey
      end
    end
  end
end

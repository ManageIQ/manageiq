describe ApplicationHelper::Button::ServerPromote do
  describe '#disabled?' do
    context "with medium priority server role" do
      before do
        @record = FactoryGirl.create(:assigned_server_role_in_master_region, :priority => 2)
      end

      it "disables the button and returns the error message" do
        view_context = setup_view_context_with_sandbox({})
        button = described_class.new(view_context, {}, {'record' => @record}, {})
        allow(view_context).to receive(:x_node).and_return('z-1r23')
        expect(button.disabled?).to be_truthy
        button.calculate_properties
        expect(button[:title]).to eq("This role can only be managed at the Region level")
      end
    end

    context "with high priority server role" do
      before do
        @record = FactoryGirl.create(:assigned_server_role_in_master_region, :priority => 1)
      end

      it "disables the button and returns the error message" do
        view_context = setup_view_context_with_sandbox({})
        button = described_class.new(view_context, {}, {'record' => @record}, {})
        allow(view_context).to receive(:x_node).and_return('z-1r23')
        expect(button.disabled?).to be_falsey
        button.calculate_properties
        expect(button[:title]).to eq(nil)
      end
    end
  end
end

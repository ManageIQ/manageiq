describe ApplicationHelper::Button::ServerPromote do
  describe '#disabled?' do
    context "record has priority == 2" do
      before do
        @record = FactoryGirl.create(:assigned_server_role, :priority => 2)
        allow(@record).to receive(:master_supported?).and_return(true)
        allow(@record.server_role).to receive(:regional_role?).and_return(true)
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

    context "record has priority == 1" do
      before do
        @record = FactoryGirl.create(:assigned_server_role, :priority => 1)
        allow(@record).to receive(:master_supported?).and_return(true)
        allow(@record.server_role).to receive(:regional_role?).and_return(true)
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

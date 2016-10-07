describe ApplicationHelper::Button::ServerDemote do
  describe '#visible?' do
    context "is assigned server role and master is supported" do
      before do
        @record = FactoryGirl.create(:assigned_server_role)
        allow(@record).to receive(:master_supported?).and_return(true)
      end

      it_behaves_like "will not be skipped for this record"
    end

    context "record is server role" do
      before do
        @record = FactoryGirl.create(:server_role, :name => "pooh")
      end

      it_behaves_like "will be skipped for this record"
    end
  end

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
        allow(button).to receive(:x_node).and_return('z-1r23')
        expect(button.disabled?).to be_truthy
        button.calculate_properties
        expect(button[:title]).to eq("This role can only be managed at the Region level")
      end
    end
  end
end

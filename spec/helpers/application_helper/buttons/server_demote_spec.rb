describe ApplicationHelper::Button::ServerDemote do
  describe '#visible?' do
    context "is assigned server role and master is supported" do
      before do
        @record = FactoryGirl.create(:assigned_server_role)
        allow(@record).to receive(:master_supported?).and_return(true)
      end

      it "will not be skipped for this record" do
        view_context = setup_view_context_with_sandbox({})
        button = described_class.new(view_context, {}, {'record' => @record}, {})
        button.instance_variable_set(:@sb, {:active_tab => "diagnostics_roles_servers"})
        allow(view_context).to receive(:x_active_tree).and_return(:diagnostics_tree)
        expect(button.visible?).to be_truthy
			end
    end

    context "record is server role" do
      before do
        @record = FactoryGirl.create(:server_role, :name => "pooh")
      end

      it "will be skipped for this record" do
        view_context = setup_view_context_with_sandbox({})
        button = described_class.new(view_context, {}, {'record' => @record}, {})
        button.instance_variable_set(:@sb, {:active_tab => "diagnostics_roles_servers"})
        allow(view_context).to receive(:x_active_tree).and_return(:diagnostics_tree)
        expect(button.visible?).to be_falsey
      end
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
        allow(view_context).to receive(:x_node).and_return('z-1r23')
        expect(button.disabled?).to be_truthy
        button.calculate_properties
        expect(button[:title]).to eq("This role can only be managed at the Region level")
      end
    end
  end
end

describe ApplicationHelper::Button::ServerDemote do
  describe '#visible?' do
    context "with master supported server role" do
      before do
        @record = FactoryGirl.create(:assigned_server_role_in_master_region)
      end

      it "will not be skipped for this record" do
        view_context = setup_view_context_with_sandbox({})
        button = described_class.new(view_context, {}, {'record' => @record}, {})
        button.instance_variable_set(:@sb, {:active_tab => "diagnostics_roles_servers"})
        allow(view_context).to receive(:x_active_tree).and_return(:diagnostics_tree)
        expect(button.visible?).to be_truthy
			end
    end

    context "without server role" do
      before do
        @record = FactoryGirl.create(:server_role)
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
    context "with medium prioirity server role" do
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
  end
end

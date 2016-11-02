describe ApplicationHelper::Button::RoleStart do
  describe '#visible?' do
    context "record is assigned server role and miq server is started" do
      before do
        @record = FactoryGirl.create(
          :assigned_server_role,
          :miq_server => FactoryGirl.create(:miq_server)
        )
        allow(@record.miq_server).to receive(:started?).and_return(true)
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
        @record = FactoryGirl.create(:server_role, :name => "biggus_dickus")
      end

      it "will be skipped for this record" do
        view_context = setup_view_context_with_sandbox({})
        button = described_class.new(view_context, {}, {'record' => @record}, {})
        button.instance_variable_set(:@sb, {:active_tab => "diagnostics_roles_servers"})
        allow(view_context).to receive(:x_active_tree).and_return(:diagnostics_tree)
        expect(button.visible?).to be_falsey
      end
    end

    context "record is miq server" do
      before do
        @record = FactoryGirl.create(:miq_server)
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
    context "record is active assigned server role" do
      before do
        @record = FactoryGirl.create(:assigned_server_role)
        allow(@record).to receive(:active?).and_return(true)
      end

      it "disables the button and returns the error message" do
        view_context = setup_view_context_with_sandbox({})
        button = described_class.new(view_context, {}, {'record' => @record}, {})
        expect(button.disabled?).to be_truthy
        button.calculate_properties
        expect(button[:title]).to eq("This Role is already active on this Server")
      end
    end

    context "record is inactive assigned server role" do
      before do
        @record = FactoryGirl.create(
          :assigned_server_role,
          :active => false,
          :miq_server => FactoryGirl.create(:miq_server)
        )
        allow(@record.miq_server).to receive(:started?).and_return(false)
      end

      it "disables the button and returns the error message" do
        view_context = setup_view_context_with_sandbox({})
        button = described_class.new(view_context, {}, {'record' => @record}, {})
        expect(button.disabled?).to be_truthy
        button.calculate_properties
        expect(button[:title]).to eq("Only available Roles on active Servers can be started")
      end
    end

    context "record is inactive assigned server role" do
      before do
        @record = FactoryGirl.create(
          :assigned_server_role,
          :active => false,
          :miq_server => FactoryGirl.create(:miq_server),
          :server_role => FactoryGirl.create(
            :server_role,
            :name => "dr_fetus"
          )
        )
        allow(@record.server_role).to receive(:regional_role?).and_return(true)
        allow(@record.miq_server).to receive(:started?).and_return(true)
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

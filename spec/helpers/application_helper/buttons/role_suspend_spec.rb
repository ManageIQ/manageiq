describe ApplicationHelper::Button::RoleSuspend do
  describe '#disabled?' do
    context "record has regional role" do
      before do
        @record = FactoryGirl.create(
          :assigned_server_role,
          :server_role => FactoryGirl.create(
              :server_role,
              :name => "terminator",
          )
        )
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

    context "record is active and max_concurrent is 1" do
      before do
        @record = FactoryGirl.create(
          :assigned_server_role,
          :active => true,
          :server_role => FactoryGirl.create(
            :server_role,
            :name => "terminator",
            :description => "cyborg"
          ),
          :miq_server => FactoryGirl.create(
            :miq_server,
            :name => "ratman"
          )
        )
        allow(@record.server_role).to receive(:regional_role?).and_return(false)
        allow(@record.server_role).to receive(:max_concurrent).and_return(1)
      end

      it "disables the button and returns the error message" do
        view_context = setup_view_context_with_sandbox({})
        button = described_class.new(view_context, {}, {'record' => @record}, {})
        allow(view_context).to receive(:x_node).and_return('z-1r23')
        expect(button.disabled?).to be_truthy
        button.calculate_properties
        expect(button[:title]).to match(/Activate the cyborg Role on another Server to suspend it on ratman \[\w+]/)
      end
    end

    context "record is inactive" do
      before do
        @record = FactoryGirl.create(
          :assigned_server_role,
          :active => false,
          :server_role => FactoryGirl.create(
            :server_role,
            :name => "terminator",
            :description => "cyborg"
          ),
          :miq_server => FactoryGirl.create(
            :miq_server,
            :name => "ratman"
          )
        )
        allow(@record.server_role).to receive(:regional_role?).and_return(false)
        allow(@record.server_role).to receive(:max_concurrent).and_return(1)
      end

      it "disables the button and returns the error message" do
        view_context = setup_view_context_with_sandbox({})
        button = described_class.new(view_context, {}, {'record' => @record}, {})
        allow(view_context).to receive(:x_node).and_return('z-1r23')
        expect(button.disabled?).to be_truthy
        button.calculate_properties
        expect(button[:title]).to eq("Only active Roles on active Servers can be suspended")
      end
    end
  end
end

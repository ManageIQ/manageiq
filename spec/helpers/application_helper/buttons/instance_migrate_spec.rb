describe ApplicationHelper::Button::InstanceMigrate do
  let(:migration_supported_vm)   { Class.new(VmOrTemplate) { supports(:live_migrate) }.new }
  let(:migration_unsupported_vm) { Class.new(VmOrTemplate) { supports_not(:live_migrate, :reason => "unavailable") }.new }
  let(:view_context)             { setup_view_context_with_sandbox({}) }

  describe '#disabled?' do
    it "when the live migrate action is available then the button is not disabled" do
      button = described_class.new(view_context, {}, {"record" => migration_supported_vm}, {})
      expect(button.disabled?).to be false
    end

    it "when the live migrate action is unavailable then the button is disabled" do
      button = described_class.new(view_context, {}, {"record" => migration_unsupported_vm}, {})
      expect(button.disabled?).to be true
    end
  end

  describe '#calculate_properties' do
    it "when the live migrate action is unavailable the button has the error in the title" do
      button = described_class.new(view_context, {}, {"record" => migration_unsupported_vm}, {})
      button.calculate_properties
      expect(button[:title]).to eq("unavailable")
    end

    it "when the live migrate is avaiable, the button has no error in the title" do
      button = described_class.new(view_context, {}, {"record" => migration_supported_vm}, {})
      button.calculate_properties
      expect(button[:title]).to be nil
    end
  end
end

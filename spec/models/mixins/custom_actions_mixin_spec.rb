RSpec.describe CustomActionsMixin do
  let(:test_class) do
    Class.new(ActiveRecord::Base) do
      def self.name; "TestClass"; end
      self.table_name = "vms"
      include CustomActionsMixin
    end
  end

  describe '#custom_actions' do
    let(:definition) { FactoryBot.create(:generic_object_definition) }
    let(:button) { FactoryBot.create(:custom_button, :name => "generic_button", :applies_to_class => "GenericObject") }
    let(:group) { FactoryBot.create(:custom_button_set, :name => "generic_button_group") }

    before { group.add_member(button) }

    context 'button group has only a hidden button' do
      before do
        allow(definition).to receive(:serialize_buttons_if_visible).and_return([])
      end

      it 'does not return with the button group' do
        expect(definition.custom_actions[:button_groups]).to be_empty
      end
    end

    it 'returns with the button group' do
      expect(definition.custom_actions[:button_groups]).not_to be_empty
    end
  end

  context 'with RBAC' do
    let(:user)                         { FactoryBot.create(:user_admin) }
    let(:cloud_tenant)                 { FactoryBot.create(:cloud_tenant) }
    let!(:custom_button_event_1) { FactoryBot.create(:custom_button_event, :target => cloud_tenant) }
    let!(:custom_button_event_2) { FactoryBot.create(:custom_button_event, :target => cloud_tenant) }

    before do
      EvmSpecHelper.create_guid_miq_server_zone
    end

    it "returns all custom button events for super admin user" do
      User.with_user(user) do
        result = Rbac::Filterer.filtered(cloud_tenant.custom_button_events)
        expect(result).to match_array([custom_button_event_1, custom_button_event_2])
      end
    end

    context "when user is non-super admin user" do
      let(:user) { FactoryBot.create(:user) }

      it "returns all custom button events" do
        User.with_user(user) do
          result = Rbac::Filterer.filtered(cloud_tenant.custom_button_events)
          expect(result).to be_empty
        end
      end
    end
  end
end

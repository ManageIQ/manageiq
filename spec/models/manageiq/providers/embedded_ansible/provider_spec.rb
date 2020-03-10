RSpec.describe ManageIQ::Providers::EmbeddedAnsible::Provider do
  subject { FactoryBot.create(:provider_embedded_ansible) }

  let(:miq_server) { FactoryBot.create(:miq_server) }

  before do
    MiqRegion.seed
    Zone.seed
    EvmSpecHelper.assign_embedded_ansible_role(miq_server)
  end

  context "DefaultAnsibleObjects concern" do
    context "with no attributes" do
      %w(organization credential inventory host).each do |obj_name|
        it "#default_#{obj_name} returns nil" do
          expect(subject.public_send("default_#{obj_name}")).to be_nil
        end

        it "#default_#{obj_name}= creates a new custom attribute" do
          subject.public_send("default_#{obj_name}=", obj_name.length)
          expect(subject.default_ansible_objects.find_by(:name => obj_name).value.to_i).to eq(obj_name.length)
        end
      end
    end

    context "with attributes saved" do
      before do
        %w(organization credential inventory host).each do |obj_name|
          subject.default_ansible_objects.create(:name => obj_name, :value => obj_name.length)
        end
      end

      %w(organization credential inventory host).each do |obj_name|
        it "#default_#{obj_name} returns the saved value" do
          expect(subject.public_send("default_#{obj_name}")).to eq(obj_name.length)
        end

        it "#default_#{obj_name}= doesn't create a second object if we pass the same value" do
          subject.public_send("default_#{obj_name}=", obj_name.length)
          expect(subject.default_ansible_objects.where(:name => obj_name).count).to eq(1)
        end
      end
    end
  end

  # The following specs are copied from the 'ansible configuration_script' spec
  # helper from the AnsibleTower Provider repo, but have been modified to make
  # sense for the case of AnsibleRunner.  Previously was:
  #
  #   it_behaves_like 'ansible provider'
  #

  describe "#destroy" do
    it "will remove all child objects" do
      subject.automation_manager.configured_systems = [
        FactoryBot.create(:configured_system_automation_manager,
                          :computer_system => FactoryBot.create(
                            :computer_system,
                            :operating_system => FactoryBot.create(:operating_system),
                            :hardware         => FactoryBot.create(:hardware)
                          ))
      ]

      subject.destroy

      expect(Provider.count).to              eq(0)
      expect(ConfiguredSystem.count).to      eq(0)
      expect(ComputerSystem.count).to        eq(0)
      expect(OperatingSystem.count).to       eq(0)
      expect(Hardware.count).to              eq(0)
    end
  end

  context "ensure_managers callback" do
    it "automatically creates an automation manager if none is provided" do
      provider = FactoryBot.create(:provider_embedded_ansible)
      expect(provider.automation_manager).to be_kind_of(ManageIQ::Providers::EmbeddedAnsible::AutomationManager)
    end

    it "sets the automation manager to disabled if created in the maintenance zone" do
      provider = FactoryBot.create(:provider_embedded_ansible, :zone => Zone.maintenance_zone)
      expect(provider.automation_manager.enabled).to eql(false)
      expect(provider.automation_manager.zone).to eql(Zone.maintenance_zone)
    end

    it "sets the automation manager to enabled if not created in the maintenance zone" do
      provider = FactoryBot.create(:provider_embedded_ansible, :zone => Zone.default_zone)
      expect(provider.automation_manager.enabled).to eql(true)
      expect(provider.automation_manager.zone).to eql(Zone.default_zone)
    end
  end
end

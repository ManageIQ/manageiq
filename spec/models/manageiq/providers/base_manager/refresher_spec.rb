RSpec.describe ManageIQ::Providers::BaseManager::Refresher do
  context "#initialize" do
    let(:ems1) { FactoryBot.create(:ext_management_system) }
    let(:ems2) { FactoryBot.create(:ext_management_system) }
    let(:vm1)  { FactoryBot.create(:vm, :ext_management_system => ems1) }
    let(:vm2)  { FactoryBot.create(:vm, :ext_management_system => ems2) }

    it "groups targets by ems" do
      refresher = described_class.new([vm1, vm2])
      expect(refresher.targets_by_ems_id.keys).to include(ems1.id, ems2.id)
    end
  end

  context "#preprocess_targets" do
    let(:ems) { FactoryBot.create(:ext_management_system) }
    let(:vm)  { FactoryBot.create(:vm, :ext_management_system => ems) }
    let(:stack) { FactoryBot.create(:orchestration_stack, :ext_management_system => ems) }
    let(:lots_of_vms) do
      num_targets = Settings.ems_refresh.full_refresh_threshold + 1
      Array.new(num_targets) { FactoryBot.create(:vm, :ext_management_system => ems) }
    end

    context "allow_targeted_refresh true" do
      before { allow(ems).to receive(:allow_targeted_refresh?).and_return(true) }
      it "does full refresh on any event" do
        refresher = described_class.new([vm])
        refresher.preprocess_targets

        targets_by_ems = refresher.targets_by_ems_id[vm.ext_management_system.id].first
        expect(targets_by_ems).to be_a(InventoryRefresh::TargetCollection)
        expect(targets_by_ems.targets.first).to eq(vm)
      end

      it "does a refresh with a stack" do
        refresher = described_class.new([stack])
        refresher.preprocess_targets

        targets_by_ems = refresher.targets_by_ems_id[stack.ext_management_system.id].first
        expect(targets_by_ems).to be_a(InventoryRefresh::TargetCollection)
        expect(targets_by_ems.targets.first).to eq(stack)
      end

      it "does a full refresh with an EMS and a VM" do
        refresher = described_class.new([vm, ems])
        refresher.preprocess_targets

        expect(refresher.targets_by_ems_id[vm.ext_management_system.id]).to eq([ems])
      end

      it "does a full refresh with a lot of targets" do
        refresher = described_class.new(lots_of_vms)
        refresher.preprocess_targets

        targets_by_ems = refresher.targets_by_ems_id[vm.ext_management_system.id].first
        expect(targets_by_ems).to be_a(ExtManagementSystem)
      end
    end

    context "allow_targeted_refresh false" do
      before { allow(ems).to receive(:allow_targeted_refresh?).and_return(false) }
      it "keeps a single vm target" do
        refresher = described_class.new([vm])
        refresher.preprocess_targets

        expect(refresher.targets_by_ems_id[vm.ext_management_system.id]).to eq([ems])
      end

      it "does a refresh with a stack" do
        refresher = described_class.new([stack])
        refresher.preprocess_targets

        expect(refresher.targets_by_ems_id[stack.ext_management_system.id].first).to eq(ems)
      end

      it "does a full refresh with an EMS and a VM" do
        refresher = described_class.new([vm, ems])
        refresher.preprocess_targets

        expect(refresher.targets_by_ems_id[vm.ext_management_system.id]).to eq([ems])
      end

      it "does a full refresh with a lot of targets" do
        refresher = described_class.new(lots_of_vms)
        refresher.preprocess_targets

        expect(refresher.targets_by_ems_id[ems.id]).to eq([ems])
      end
    end
  end

  context "#publish_inventory" do
    # Create a simple persister class with just two collections

    let(:ems) { FactoryBot.create(:ext_management_system, :name => "my-ems") }
    let(:messaging_client) { double("ManageIQ::Messaging::Client") }
    let(:persister) { Spec::Support::EmsRefreshHelper::TestPersister.new(ems) }

    before do
      stub_settings_merge(:ems_refresh => {:syndicate_inventory => true}, :messaging => {:type => 'kafka'})
      allow(MiqQueue).to receive(:messaging_client).and_return(messaging_client)
    end

    context "with no inventory" do
      it "doesn't publish anything" do
        expect(messaging_client).not_to receive(:publish_topic)

        persister.publish_inventory(ems, ems)
      end
    end

    context "with a single inventory object" do
      before { persister.vms.build(:ems_ref => "vm-1") }

      it "publishes inventory to kafka" do
        expect(messaging_client).to receive(:publish_topic).once.with(
          array_including(
            hash_including(
              :service => "manageiq.ems-inventory",
              :sender  => "#{ems.emstype}__#{ems.id}",
              :event   => "#{ems.emstype}__#{ems.id}__vms__vm-1",
              :payload => hash_including(
                :collection => :vms,
                :data       => hash_including(
                  :ems_ref => "vm-1"
                )
              )
            )
          )
        )

        persister.publish_inventory(ems, ems)
      end
    end

    context "with lazy references between objects" do
      before do
        persister.vms.build(:ems_ref => "vm-1", :host => persister.hosts.lazy_find("host-1"))
        persister.hosts.build(:ems_ref => "host-1")
      end

      it "publishes inventory to kafka" do
        expect(messaging_client).to receive(:publish_topic).once.with(
          array_including(
            hash_including(
              :service => "manageiq.ems-inventory",
              :sender  => "#{ems.emstype}__#{ems.id}",
              :event   => "#{ems.emstype}__#{ems.id}__vms__vm-1",
              :payload => hash_including(
                :collection => :vms,
                :data       => hash_including(
                  :ems_ref => "vm-1",
                  :host    => hash_including(
                    :inventory_collection_name => :hosts,
                    :ref                       => :manager_ref,
                    :reference                 => {:ems_ref => "host-1"}
                  )
                )
              )
            )
          )
        )
        expect(messaging_client).to receive(:publish_topic).once.with(
          array_including(
            hash_including(
              :service => "manageiq.ems-inventory",
              :sender  => "#{ems.emstype}__#{ems.id}",
              :event   => "#{ems.emstype}__#{ems.id}__hosts__host-1",
              :payload => hash_including(
                :collection => :hosts,
                :data       => hash_including(
                  :ems_ref => "host-1"
                )
              )
            )
          )
        )

        persister.publish_inventory(ems, ems)
      end
    end
  end
end

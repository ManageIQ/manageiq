describe ManageIQ::Providers::Azure::CloudManager::EventCatcher::Runner do
  context "parsing properties" do
    let(:ems) { FactoryGirl.create(:ems_azure_with_authentication) }
    let(:catcher) { described_class.new(:ems_id => ems.id) }

    let(:event) do
      {"authorization" => {"action" => "Microsoft.Compute/virtualMachines/deallocate/action"},
       "eventName"     => {"value"  => "EndRequest"},
       "resourceId"    => "/subscriptions/12345/resourceGroups/Rg1/providers/Microsoft.Compute/virtualMachines/TestVm"}
    end

    before do
      allow_any_instance_of(ManageIQ::Providers::Azure::CloudManager).to receive_messages(:authentication_check => [true, ""])
      allow_any_instance_of(MiqWorker::Runner).to receive(:worker_initialization)
    end

    describe "parse properties" do
      it "event type" do
        expect(catcher.parse_event_type(event)).to eq "virtualMachines_deallocate_EndRequest"
      end

      it "vm ref" do
        expect(catcher.parse_vm_ref(event)).to eq "12345\\rg1\\microsoft.compute/virtualmachines\\TestVm"
      end
    end
  end
end

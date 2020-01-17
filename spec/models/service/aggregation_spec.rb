RSpec.describe Service do
  it "#aggregate_all_vm_memory_on_disk will not raise when the attribute is nil" do
    service = FactoryBot.create(:service)
    expect(service).to receive(:has_attribute?).with("aggregate_all_vm_memory_on_disk").and_return(true)
    expect { service.aggregate_all_vm_memory_on_disk }.not_to raise_error
  end
end

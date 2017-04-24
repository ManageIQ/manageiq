describe "Service" do
  before(:each) do
    @server = EvmSpecHelper.local_miq_server
    @service = FactoryGirl.create(:service)
  end

  it "will not crash when the attribute  is nil" do
    allow(@service).to receive(:has_attribute?).with("aggregate_all_vm_memory_on_disk").and_return(true)
    expect { @service.aggregate_all_vm_memory_on_disk }.not_to raise_error
  end
end

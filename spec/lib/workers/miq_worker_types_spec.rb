describe "worker types lists" do
  let(:all_defined_workers) do
    exceptions = %w[ManageIQ::Providers::BaseManager::OperationsWorker]
    MiqWorker.descendants.select { |w| w.subclasses.empty? }.map(&:name) - exceptions
  end

  it "should include all the worker types" do
    expect(MIQ_WORKER_TYPES.keys).to match_array(all_defined_workers)
  end

  it "kill list should match type list" do
    expect(MIQ_WORKER_TYPES_IN_KILL_ORDER).to match_array(all_defined_workers)
  end
end

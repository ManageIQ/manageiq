require "spec_helper"

describe MiqUiWorker::Runner do
  it ".wait_for_worker_monitor?" do
    expect(described_class.wait_for_worker_monitor?).to be_false
  end
end

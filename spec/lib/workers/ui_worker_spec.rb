require "spec_helper"

require "workers/ui_worker"

describe UiWorker do
  it ".wait_for_worker_monitor?" do
    expect(described_class.wait_for_worker_monitor?).to be_false
  end
end

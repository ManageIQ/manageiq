require "spec_helper"

describe VmdbMetric do
  before(:each) do
    EvmSpecHelper.create_guid_miq_server_zone
  end

  it "should purge" do
    expect {
      VmdbMetric.purge_daily_timer
      VmdbMetric.purge_daily_timer
    }.to change { MiqQueue.count }.by(1)
  end
end

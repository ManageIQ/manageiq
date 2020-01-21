describe VmdbMetric do
  before do
    EvmSpecHelper.create_guid_miq_server_zone
  end

  it "should purge" do
    expect do
      VmdbMetric.purge_daily_timer
    end.to(change { MiqQueue.count }.by(1))
  end
end

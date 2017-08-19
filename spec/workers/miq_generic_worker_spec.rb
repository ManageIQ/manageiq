describe MiqGenericWorker, :use_fixtures => false do
  let(:cmd)     { "ruby #{run_single_worker_bin} -b MiqGenericWorker" }
  let(:command) { last_command_started }
  let(:hb_file) { "generic_worker.hb" }

  before do
    # This needs to be read properly from the spawned process, so we either
    # need to create or use the existing guid in the project
    #
    # Also, zone must be a zone named "default" to work with the default
    # settings in sync_config
    server = EvmSpecHelper.remote_miq_server(:guid => MiqServer.my_guid, :zone_name => "default")

    set_environment_variable("WORKER_HEARTBEAT_FILE", expand_path(hb_file))
    set_environment_variable("WORKER_HEARTBEAT_METHOD", "file")
    run_command(cmd, :startup_wait_time => 10)
  end

  it "starts and heartbeats properly" do
    expect(hb_file).to be_an_existing_file
  end
end

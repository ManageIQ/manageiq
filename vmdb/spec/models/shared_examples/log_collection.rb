shared_examples_for "Log Collection #synchronize_logs" do |type|
  let(:instance) { instance_variable_get("@#{type}") }

  it "#{type.camelize} no args" do
    LogFile.should_receive(:logs_from_server).with(MiqServer.my_server, {})

    instance.synchronize_logs
  end

  it "#{type.camelize} with options" do
    LogFile.should_receive(:logs_from_server).with(MiqServer.my_server, :only_current => true)

    instance.synchronize_logs(:only_current => true)
  end

  it "#{type.camelize} user with options" do
    LogFile.should_receive(:logs_from_server).with("test", MiqServer.my_server, :only_current => false)

    instance.synchronize_logs("test", :only_current => false)
  end
end

shared_examples_for "Log Collection should create 1 task and 1 queue item" do
  it "should create 1 task" do
    expect(@tasks.length).to       eq(1)
    expect(@task.id).to            eq(@task_id)
    expect(@task.miq_server_id).to eq(@miq_server.id)
    expect(@task.name).to          include("Zipped log retrieval")
  end

  it "should create 1 queue message" do
    expect(@messages.length).to    eq(1)
    expect(@message.args.first).to eq(:taskid => @task.id, :klass => @miq_server.class.name, :id => @miq_server.id)
  end
end

shared_examples_for "Log Collection should create 0 tasks and 0 queue items" do
  it "should create 0 unfinished tasks" do
    expect(MiqTask.count(:conditions => ["state != ?", "Finished"])).to eq(0)
  end

  it "should create 0 queue messages" do
    expect(MiqQueue.count(:conditions => ["state not in (?)", ["ok", "ready", "error"]])).to eq(0)
  end
end

shared_examples_for "Log Collection should error out task and queue item" do
  it "should error out queue item through queue callback" do
    expect(["timeout", "error"]).to include(@message.state)
  end

  it "should error out task item queue callback" do
    @task.reload

    expect(@task.state).to          eq("Finished")
    expect(["Timeout", "Error"]).to include(@task.status)
  end
end

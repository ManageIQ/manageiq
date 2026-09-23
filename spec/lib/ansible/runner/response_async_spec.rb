RSpec.describe Ansible::Runner::ResponseAsync do
  let(:runner_class)   { "Floe::ContainerRunner::Docker" }
  let(:runner_context) { {"container_ref" => "floe-ansible-ee-abc123", "container_state" => {"Running" => false, "ExitCode" => 0}} }
  let(:base_dir)       { Dir.mktmpdir("ansible-runner") }
  let(:runner_double)  { instance_double(Floe::ContainerRunner::Docker) }

  subject(:response_async) do
    described_class.new(
      :runner_class   => runner_class,
      :runner_context => runner_context,
      :base_dir       => base_dir,
      :debug          => false
    )
  end

  after { FileUtils.rm_rf(base_dir) }

  before do
    allow(Floe::ContainerRunner::Docker).to receive(:new).and_return(runner_double)
  end

  describe "#running?" do
    it "delegates status! and running? to the Floe runner" do
      expect(runner_double).to receive(:status!).with(runner_context)
      expect(runner_double).to receive(:running?).with(runner_context).and_return(true)

      expect(response_async.running?).to be true
    end

    it "returns false when the container has exited" do
      expect(runner_double).to receive(:status!).with(runner_context)
      expect(runner_double).to receive(:running?).with(runner_context).and_return(false)

      expect(response_async.running?).to be false
    end
  end

  describe "#stop" do
    it "calls cleanup on the runner and removes base_dir" do
      expect(runner_double).to receive(:cleanup).with(runner_context)

      response_async.stop

      expect(File.exist?(base_dir)).to be false
    end

    it "does not remove base_dir when debug is true" do
      response = described_class.new(
        :runner_class   => runner_class,
        :runner_context => runner_context,
        :base_dir       => base_dir,
        :debug          => true
      )

      expect(runner_double).to receive(:cleanup).with(runner_context)

      response.stop

      expect(File.exist?(base_dir)).to be true
    end
  end

  describe "#response" do
    before do
      allow(runner_double).to receive(:status!).with(runner_context)
      allow(runner_double).to receive(:running?).with(runner_context).and_return(false)
    end

    it "returns nil while still running" do
      allow(runner_double).to receive(:running?).with(runner_context).and_return(true)

      expect(response_async.response).to be_nil
    end

    it "returns an Ansible::Runner::Response when finished successfully" do
      stdout_json = {"event" => "runner_on_ok", "stdout" => "ok"}.to_json

      expect(runner_double).to receive(:output).with(runner_context).and_return(stdout_json)
      expect(runner_double).to receive(:success?).with(runner_context).and_return(true)
      expect(runner_double).to receive(:cleanup).with(runner_context)

      result = response_async.response

      expect(result).to be_a(Ansible::Runner::Response)
      expect(result.return_code).to eq(0)
      expect(result.stdout).to eq(stdout_json)
    end

    it "returns an Ansible::Runner::Response with return_code 1 on failure" do
      expect(runner_double).to receive(:output).with(runner_context).and_return("")
      expect(runner_double).to receive(:success?).with(runner_context).and_return(false)
      expect(runner_double).to receive(:cleanup).with(runner_context)

      result = response_async.response

      expect(result).to be_a(Ansible::Runner::Response)
      expect(result.return_code).to eq(1)
    end

    it "memoises the response object" do
      allow(runner_double).to receive(:output).with(runner_context).and_return("")
      allow(runner_double).to receive(:success?).with(runner_context).and_return(true)
      allow(runner_double).to receive(:cleanup).with(runner_context)

      first  = response_async.response
      second = response_async.response

      expect(first).to be(second)
    end
  end

  describe "#dump" do
    it "returns a hash with all required keys" do
      dumped = response_async.dump

      expect(dumped).to eq(
        :runner_class   => runner_class,
        :runner_context => runner_context,
        :base_dir       => base_dir.to_s,
        :debug          => false
      )
    end
  end

  describe ".load" do
    it "recreates a ResponseAsync from a dumped hash" do
      dumped   = response_async.dump
      reloaded = described_class.load(dumped)

      expect(reloaded.runner_class).to   eq(Floe::ContainerRunner::Docker)
      expect(reloaded.runner_context).to eq(runner_context)
      expect(reloaded.base_dir.to_s).to  eq(base_dir.to_s)
      expect(reloaded.debug).to          eq(false)
    end

    it "round-trips through dump/load and still operates correctly" do
      reloaded = described_class.load(response_async.dump)

      allow(runner_double).to receive(:status!).with(runner_context)
      allow(runner_double).to receive(:running?).with(runner_context).and_return(false)
      allow(runner_double).to receive(:output).with(runner_context).and_return("")
      allow(runner_double).to receive(:success?).with(runner_context).and_return(true)
      allow(runner_double).to receive(:cleanup).with(runner_context)

      result = reloaded.response
      expect(result).to be_a(Ansible::Runner::Response)
      expect(result.return_code).to eq(0)
    end
  end
end

RSpec.describe Ansible::Runner::Response do
  subject { described_class.new(:base_dir => base_dir, :ident => ident) }

  let(:ident)        { described_class.new(:base_dir => '').ident }
  let(:base_dir)     { File.expand_path("../../../..", job_events.first.path) } # triggers job_events
  let(:runner_dir)   { Dir.mktmpdir("runner_run") } # same as base_dir
  let(:stdout_lines) { "\n" }

  let(:job_events) do
    stdout_lines.lines.map.with_index do |line, index|
      filename = File.join(job_events_dir, "#{index + 1}-#{SecureRandom.uuid}.json")
      File.open(filename, "w") do |file|
        file.write(line)
        file
      end
    end
  end

  let(:job_events_dir) do
    File.join(runner_dir, "artifacts", ident, "job_events").tap do |dir|
      FileUtils.mkdir_p(dir)
    end
  end

  let(:good_stdout) do
    <<~LINES
      {"uuid": "d737fa4a", "counter": 1, "stdout": "", "start_line": 0, "end_line": 0}
      {"uuid": "080027c4", "counter": 2, "stdout": "\\r\\nPLAY [List Variables] **********************************************************", "start_line": 0, "end_line": 2}
      {"uuid": "080027c4", "counter": 3, "stdout": "\\r\\nTASK [Gathering Facts] *********************************************************", "start_line": 2, "end_line": 4}
      {"uuid": "7f4409f5", "counter": 4, "stdout": "", "start_line": 4, "end_line": 4}
    LINES
  end

  after do
    FileUtils.rm_rf(runner_dir) if Dir.exist?(runner_dir)
  end

  describe "#stdout" do
    context "with no stdout file" do
      it "returns an empty string" do
        subject
        FileUtils.rm_rf(Dir.glob(File.join(job_events_dir, "*.json")))

        expect(subject.stdout).to eq("")
      end
    end

    context "with valid stdout (1 JSON object per line)" do
      let(:stdout_lines) { good_stdout }

      it "returns all the content" do
        expect(subject.stdout).to eq(good_stdout)
      end
    end
  end

  describe "#parsed_stdout" do
    context "with no stdout file" do
      it "returns an empty array" do
        subject
        FileUtils.rm_rf(Dir.glob(File.join(job_events_dir, "*.json")))

        expect(subject.parsed_stdout).to eq([])
      end
    end

    context "with valid stdout (1 JSON object per line)" do
      let(:stdout_lines) { good_stdout }

      it "returns an array of only hashes" do
        expect(subject.parsed_stdout.all? { |line| line.kind_of?(Hash) }).to be_truthy
      end

      it "includes the expected 'stdout' keys" do
        expect(subject.parsed_stdout[0]['stdout']).to eq("")
        expect(subject.parsed_stdout[1]['stdout']).to eq("\r\nPLAY [List Variables] **********************************************************")
        expect(subject.parsed_stdout[2]['stdout']).to eq("\r\nTASK [Gathering Facts] *********************************************************")
        expect(subject.parsed_stdout[3]['stdout']).to eq("")
      end
    end

    context "with a different :ident provided" do
      let(:ident)        { 'my_result' }
      let(:stdout_lines) { good_stdout }

      it "returns an array of only hashes" do
        expect(subject.parsed_stdout.all? { |line| line.kind_of?(Hash) }).to be_truthy
      end

      it "includes the expected 'stdout' keys" do
        expect(subject.parsed_stdout[0]['stdout']).to eq("")
        expect(subject.parsed_stdout[1]['stdout']).to eq("\r\nPLAY [List Variables] **********************************************************")
        expect(subject.parsed_stdout[2]['stdout']).to eq("\r\nTASK [Gathering Facts] *********************************************************")
        expect(subject.parsed_stdout[3]['stdout']).to eq("")
      end
    end
  end
end

RSpec.describe Ansible::Runner::Response do
  let(:good_stdout) do
    <<~LINES
      {"uuid": "d737fa4a", "counter": 1, "stdout": "", "start_line": 0, "end_line": 0}
      {"uuid": "080027c4", "counter": 2, "stdout": "\\r\\nPLAY [List Variables] **********************************************************", "start_line": 0, "end_line": 2, "event": "playbook_on_play_start", "event_data": {"play": "List Variables"}}
      {"uuid": "080027c4", "counter": 3, "stdout": "\\r\\nTASK [Gathering Facts] *********************************************************", "start_line": 2, "end_line": 4}
      [WARNING]: This is a warning from ansible
      {"uuid": "7f4409f5", "counter": 4, "stdout": "ok: [localhost]", "start_line": 4, "end_line": 5, "event": "runner_on_ok", "event_data": {}}
      {"uuid": "8e3f1a22", "counter": 5, "stdout": "", "start_line": 5, "end_line": 5, "event": "playbook_on_stats", "event_data": {"artifact_data": {"var_a": "val_a"}}}
    LINES
  end

  let(:good_stdout_human) do
    [
      "",
      "\r\nPLAY [List Variables] **********************************************************",
      "\r\nTASK [Gathering Facts] *********************************************************",
      "[WARNING]: This is a warning from ansible",
      "ok: [localhost]",
      "",
    ].join("\n")
  end

  subject { described_class.new(:return_code => 0, :stdout => good_stdout) }

  describe "#return_code" do
    it "returns the value passed at construction" do
      expect(subject.return_code).to eq(0)
    end

    it "returns non-zero for failure" do
      expect(described_class.new(:return_code => 1, :stdout => "").return_code).to eq(1)
    end
  end

  describe "#stdout" do
    it "returns the raw stdout string" do
      expect(subject.stdout).to eq(good_stdout)
    end
  end

  describe "#parsed_stdout" do
    it "returns an array of hashes" do
      expect(subject.parsed_stdout).to all(be_a(Hash))
    end

    it "parses stdout fields from JSON events" do
      expect(subject.parsed_stdout[0]["stdout"]).to eq("")
      expect(subject.parsed_stdout[1]["stdout"]).to eq("\r\nPLAY [List Variables] **********************************************************")
      expect(subject.parsed_stdout[2]["stdout"]).to eq("\r\nTASK [Gathering Facts] *********************************************************")
      expect(subject.parsed_stdout[4]["stdout"]).to eq("ok: [localhost]")
      expect(subject.parsed_stdout[5]["stdout"]).to eq("")
    end

    it "wraps non-JSON lines from the stream as stdout hashes" do
      expect(subject.parsed_stdout[3]).to eq("stdout" => "[WARNING]: This is a warning from ansible")
    end

    it "returns an empty array for empty stdout" do
      response = described_class.new(:return_code => 0, :stdout => "")
      expect(response.parsed_stdout).to eq([])
    end

    it "wraps non-JSON lines mixed with JSON lines" do
      response = described_class.new(:return_code => 0, :stdout => "not json\n{\"stdout\": \"ok\"}\n")
      expect(response.parsed_stdout).to eq([{"stdout" => "not json"}, {"stdout" => "ok"}])
    end
  end

  describe "#human_stdout" do
    it "joins the stdout fields from each event" do
      expect(subject.human_stdout).to eq(good_stdout_human)
    end

    it "returns an empty string for empty stdout" do
      response = described_class.new(:return_code => 0, :stdout => "")
      expect(response.human_stdout).to eq("")
    end
  end

  describe "#plays" do
    it "returns an array of playbook_on_play_start events" do
      expect(subject.plays.size).to eq(1)
      expect(subject.plays.first["event_data"]["play"]).to eq("List Variables")
    end

    it "returns an empty array when no play events exist" do
      response = described_class.new(:return_code => 0, :stdout => "")
      expect(response.plays).to eq([])
    end
  end

  describe "#stats" do
    it "returns the artifact_data from the stats event" do
      expect(subject.stats).to eq("var_a" => "val_a")
    end

    it "returns an empty hash when no stats event exists" do
      response = described_class.new(:return_code => 0, :stdout => "")
      expect(response.stats).to eq({})
    end
  end

  describe ".parsed_stdout_to_human" do
    it "joins the stdout fields" do
      expect(described_class.parsed_stdout_to_human(subject.parsed_stdout)).to eq(good_stdout_human)
    end

    it "returns an empty string for an empty array" do
      expect(described_class.parsed_stdout_to_human([])).to eq("")
    end
  end

  describe ".parsed_stdout_to_plays" do
    it "extracts playbook_on_play_start events" do
      expect(described_class.parsed_stdout_to_plays(subject.parsed_stdout).pluck("event")).to eq(["playbook_on_play_start"])
    end
  end

  describe ".parsed_stdout_to_stats" do
    it "extracts artifact_data from playbook_on_stats event" do
      expect(described_class.parsed_stdout_to_stats(subject.parsed_stdout)).to eq("var_a" => "val_a")
    end

    it "returns empty hash when missing" do
      expect(described_class.parsed_stdout_to_stats([])).to eq({})
    end
  end
end

require 'util/miq-process'

describe MiqProcess do
  context ".command_line" do
    it "exited process" do
      allow(Sys::ProcTable).to receive(:ps).and_return nil
      expect(described_class.command_line(123)).to eq ""
    end

    it "no permissions to proctable info" do
      allow(Sys::ProcTable).to receive(:ps).and_return(double(:cmdline => nil))
      expect(described_class.command_line(123)).to eq ""
    end

    it "normal case" do
      expect(described_class.command_line(Process.pid)).not_to be_empty
    end
  end
end

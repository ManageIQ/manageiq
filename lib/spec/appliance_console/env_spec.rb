require "spec_helper"
require "appliance_console/env"

describe ApplianceConsole::Env do
  before do
    described_class.stub(:`).and_raise("Spawning is not permitted in specs.  Please add stubs to your spec")
    described_class.clear_errors
  end

  subject do
    described_class
  end

  it "should call net_file if it exists (and upcase name)" do
    subject.should_receive(:`).with(/-GET IP/).and_return("10.10.10.10\n")
    File.should_receive(:exist?).and_return(true)
    expect(subject[:ip]).to eq("10.10.10.10")
  end

  it "should just return value if net_file doesn't exits" do
    subject.should_not_receive(:`)
    File.should_receive(:exist?).and_return(false)
    expect(subject["IP"]).to eq("IP")
  end

  it "should upcase set name" do
    subject.should_receive(:`).with(/-IP abc/).and_return("")
    File.should_receive(:exist?).and_return(true)
    subject[:ip] = "abc"
  end

  it "should know something changed if calling set" do
    subject.should_receive(:`).with(/-DHCP ABC +2>/).and_return("")
    File.should_receive(:exist?).and_return(true)
    subject["DHCP"] = "ABC"
    expect(subject).to be_changed
  end

  it "should not pass true values to command line" do
    subject.should_receive(:`).with(/-DHCP +2>/).and_return("")
    File.should_receive(:exist?).and_return(true)
    subject["DHCP"] = true
    expect(subject).to be_changed
  end

  it "should do nothing if setting a variable to false" do
    File.should_not_receive(:exist?)
    subject["DHCP"] = false
    expect(subject).not_to be_changed
  end

  it "should do nothing if setting a variable to nil" do
    File.should_not_receive(:exist?)
    subject["DHCP"] = nil
    expect(subject).not_to be_changed
  end

  it "should know something changed if calling rake" do
    subject.should_receive(:`).with(/runner.*rake/).and_return("")
    subject.rake("something")
    expect(subject).to be_changed
  end

  it "should clear changed" do
    subject.should_receive(:`).with(/runner.*rake/).and_return("")
    subject.rake("something")
    expect(subject).to be_changed

    subject.clear_errors

    expect(subject).not_to be_changed
  end
end

require "appliance_console/prompts"
require "appliance_console/key_configuration"

describe ApplianceConsole::KeyConfiguration do
  context "#ask_questions" do
    subject { Class.new(described_class).tap { |c| c.send(:include, ApplianceConsole::Prompts) }.new }

    context "creating" do
      it "asks for nothing else" do
        v2_exists(false)
        expect(subject).to receive(:ask_with_menu).with(/key/i, anything, :create, false).and_return(:create)
        expect(subject).not_to receive(:just_ask)
        expect(subject.ask_questions).to be_truthy
      end

      it "defaults to action" do
        v2_exists(false)
        subject.action = :fetch
        expect(subject).to receive(:ask_with_menu).with(/key/i, anything, :fetch, false).and_return(:create)
        expect(subject).not_to receive(:just_ask)
        expect(subject.ask_questions).to be_truthy
      end
    end

    context "fetch" do
      it "asks for other parameters" do
        v2_exists(false)
        expect(subject).to receive(:ask_with_menu).with(/key/i, anything, :create, false).and_return(:fetch)
        expect(subject).to receive(:say).with("")
        expect(subject).to receive(:just_ask).with(/host/i, nil, anything, anything).and_return("newhost")
        expect(subject).to receive(:just_ask).with(/login/i, "root").and_return("root")
        expect(subject).to receive(:just_ask).with(/password/i, nil).and_return("password")
        expect(subject).to receive(:just_ask).with(/path/i, /v2_key$/).and_return("/remote/path/v2_key")
        expect(subject.ask_questions).to be_truthy
      end
    end

    context "with existing key" do
      it "fails if dont overwrite" do
        v2_exists
        expect(subject).to receive(:agree).with(/overwrite/i).and_return(false)
        expect(subject).not_to receive(:ask_with_menu)
        expect(subject.ask_questions).not_to be_truthy
      end

      it "succeeds if overwrite" do
        v2_exists
        expect(subject).to receive(:agree).with(/overwrite/i).and_return(true)
        expect(subject).to receive(:ask_with_menu).and_return(:create)
        expect(subject.ask_questions).to be_truthy
        expect(subject.force).to be_truthy
      end
    end
  end

  context "with host defined" do
    let(:host) { "master.miqmachines.com" }
    let(:password) { "super secret" }
    subject { described_class.new(:action => :fetch, :host => host, :password => password) }

    context "#activate" do
      context "with no existing key" do
        it "fetches key" do
          v2_exists(false) # before download
          v2_exists(true)  # after downloaded
          expect(Net::SCP).to receive(:start).with(host, "root", :password => password)
          expect(subject.activate).to be_truthy
        end

        it "creates key" do
          subject.action = :create
          v2_exists(false)
          expect(MiqPassword).to receive(:generate_symmetric).and_return(154)
          expect(subject.activate).to be_truthy
        end
      end

      context "with existing key" do
        it "removes existing key" do
          subject.force = true
          v2_exists(true) # before downloaded
          v2_exists(true) # after downloaded
          expect(FileUtils).to receive(:rm).with(/v2_key/).and_return(["v2_key"])
          scp = double('scp')
          expect(scp).to receive(:download!).with(subject.key_path, /v2_key/).and_return(:result)
          expect(Net::SCP).to receive(:start).with(host, "root", :password => password).and_yield(scp).and_return(true)
          expect(subject.activate).to be_truthy
        end

        it "fails if key exists (no force)" do
          expect($stderr).to receive(:puts).at_least(2).times
          subject.force = false
          v2_exists(true)
          expect(FileUtils).not_to receive(:rm)
          expect(Net::SCP).not_to receive(:start)
          expect(subject.activate).to be_falsey
        end
      end
    end
  end

  private

  def v2_exists(value = true)
    expect(File).to receive(:exist?).with(/v2/).and_return(value)
  end
end

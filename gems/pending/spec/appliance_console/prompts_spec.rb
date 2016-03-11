require "stringio"
require "appliance_console/errors"
require "appliance_console/prompts"
require "active_support/all"
require 'highline/import'
require "linux_admin"

describe ApplianceConsole::Prompts do
  let(:input)  { StringIO.new }
  let(:output) { StringIO.new }

  let(:prompt)  { "\n?  " }

  subject do
    Class.new(HighLine) { include ApplianceConsole::Prompts }.new(input, output)
  end

  # net/ssh messes with track_eof
  # we need it for testing
  # set it back after we are done

  before do
    @old_track, HighLine.track_eof = HighLine.track_eof?, true
  end

  after do
    HighLine.track_eof = @old_track
  end

  context "#sample_url" do
    it "should show an example for nfs" do
      expect(subject.sample_url('nfs')).to match(%r{nfs://})
    end

    it "should show an example for smb" do
      expect(subject.sample_url('smb')).to match(%r{smb://})
    end
  end

  context "#ask_for_remote_backup_uri" do
    it "should ask for smb uri" do
      response = "smb://host.com/path/file.txt"
      say response
      expect(subject.ask_for_uri("prompt", "smb")).to eq(response)
      expect_heard("Enter the prompt: ")
    end

    it "should ensure correct scheme" do
      response = "nfs://host.com/path/file.txt"
      say ["smb://host.com/path/file.txt", response]
      expect(subject.ask_for_uri("prompt", "nfs")).to eq(response)
      expect_heard ["Enter the prompt: ", "Please provide a valid URI", prompt]
    end

    it "should ensure uri" do
      response = "nfs://host.com/path/file.txt"
      say ["x", response]
      expect(subject.ask_for_uri("prompt", "nfs")).to eq(response)
      expect_heard ["Enter the prompt: ", "Please provide a valid URI", prompt]
    end
  end

  context "#ask_for_many" do
    it "should leverage default" do
      say ""
      expect(subject.ask_for_many("word", "words", "default_word")).to eq(["default_word"])
      expect_heard ["Enter the words: |default_word| "]
    end

    it "should support a blanke response" do
      say ""
      expect(subject.ask_for_many("word")).to eq([])
      expect_heard ["Enter the words: "]
    end

    ["  ", ";", ", "].each do |splitter|
      it "should parse phrases separated by '#{splitter}'" do
        say %w(a b c).join(splitter)
        expect(subject.ask_for_many("word")).to eq(%w(a b c))
        expect_heard ["Enter the words: "]
      end
    end

    it "should limit the resposne, shorter than 255, and fewer than 7 words" do
      error = "Please provide up to 6 words separated by a space and up to 255 characters"
      say ["a" * 256, %w(1 2 3 4 5 6 7).join(" "), %w(1 2 3).join(",")]
      expect(subject.ask_for_many("word", "phrase")).to eq(%w(1 2 3))
      expect_heard ["Enter the phrase: ", error, prompt, error, prompt]
    end
  end

  it "should ask for any key" do
    expect(subject).to receive(:say)
    expect(STDIN).to receive(:getc)
    subject.press_any_key
  end

  it "should print for a clear screen" do
    expect(subject).to receive(:print)
    subject.clear_screen
  end

  context "#are_you_sure?" do
    it "should ask are you sure without clarifier" do
      prompt = "Are you sure? (Y/N): "
      error = %(Please enter "yes" or "no".\n)
      say %w(um yes)
      expect(subject.are_you_sure?).to be_truthy
      expect_heard [prompt + error, prompt]
    end

    it "should ask are you sure with clarifier" do
      say ["no"]
      expect(subject.are_you_sure?("x y")).to be_falsey
      expect_heard "Are you sure you want to x y? (Y/N): ", false
    end

    it "should ask are you sure with complete clarifier" do
      say ["no"]
      expect(subject.are_you_sure?(" you dont want to x y")).to be_falsey
      expect_heard "Are you sure you dont want to x y? (Y/N): ", false
    end
  end

  context "#ask_for_ip" do
    it "should prompt for ip" do
      say %w(bad 1.1.1.1)
      expect(subject.ask_for_ip("prompt", nil)).to eq("1.1.1.1")
      expect_heard ["Enter the prompt: ", "Please provide a valid IP Address.", prompt]
    end

    it "should default ip prompts" do
      say ""
      expect(subject.ask_for_ip("prompt", "1.1.1.1")).to eq("1.1.1.1")
      expect_heard "Enter the prompt: |1.1.1.1| "
    end

    context "#or_none" do
      it "should handle default" do
        say ""
        expect(subject.ask_for_ip_or_none("prompt", "1.1.1.1")).to eq("1.1.1.1")
        expect_heard("Enter the prompt: |1.1.1.1| ")
      end

      it "should handle blank" do
        say ""
        expect(subject.ask_for_ip_or_none("prompt")).to eq("")
        expect_heard("Enter the prompt: ")
      end

      it "should handle none" do
        say "none"
        expect(subject.ask_for_ip_or_none("prompt", "1.1.1.1")).to eq("")
        expect_heard("Enter the prompt: |1.1.1.1| ")
      end
    end

    context "#or hostname" do
      it "should handle default" do
        say ""
        expect(subject.ask_for_ip_or_hostname("prompt", "1.1.1.1")).to eq("1.1.1.1")
        expect_heard("Enter the prompt: |1.1.1.1| ")
      end

      it "should handle ip address" do
        say "2.2.2.2"
        expect(subject.ask_for_ip_or_hostname("prompt", "1.1.1.1")).to eq("2.2.2.2")
        expect_heard("Enter the prompt: |1.1.1.1| ")
      end

      it "should handle hostname" do
        say %w(5x redhat.com)
        expect(subject.ask_for_ip_or_hostname("prompt", "1.1.1.1")).to eq("redhat.com")
        expect_heard ["Enter the prompt: |1.1.1.1| ", "Please provide a valid Hostname or IP Address.", prompt]
      end
    end

    context "#or hostname or none" do
      it "should handle handle default" do
        say ""
        expect(subject.ask_for_ip_or_hostname_or_none("prompt", "1.1.1.1")).to eq("1.1.1.1")
        expect_heard("Enter the prompt: |1.1.1.1| ")
      end

      it "should handle ip address" do
        say "2.2.2.2"
        expect(subject.ask_for_ip_or_hostname_or_none("prompt", "1.1.1.1")).to eq("2.2.2.2")
        expect_heard("Enter the prompt: |1.1.1.1| ")
      end

      it "should handle hostname" do
        say %w(5x redhat.com)
        expect(subject.ask_for_ip_or_hostname_or_none("prompt", "1.1.1.1")).to eq("redhat.com")
        expect_heard ["Enter the prompt: |1.1.1.1| ", "Please provide a valid Hostname or IP Address.", prompt]
      end

      it "should handle blank" do
        say ""
        expect(subject.ask_for_ip_or_hostname_or_none("prompt")).to eq("")
        expect_heard("Enter the prompt: ")
      end

      it "should handle none" do
        say "none"
        expect(subject.ask_for_ip_or_hostname_or_none("prompt", "1.1.1.1")).to eq("")
        expect_heard("Enter the prompt: |1.1.1.1| ")
      end
    end
  end

  context "#passwords" do
    it "should prompt for a password" do
      say "secret"
      expect(subject.ask_for_password("prompt")).to eq("secret")
      expect_heard ["Enter the prompt: ", "******", ""]
    end

    it "should not display default password)" do
      say ""
      expect(subject.ask_for_password("prompt", "defaultpass")).to eq("defaultpass")
      expect_heard ["Enter the prompt: |********| ", ""]
    end

    context "#or_none" do
      it "should not append none if no default password" do
        say "secret"
        expect(subject.ask_for_password_or_none("prompt", nil)).to eq("secret")
        expect_heard ["Enter the prompt: ", "******", ""]
      end

      it "should not botch passwords" do
        say "secret"
        expect(subject.ask_for_password_or_none("prompt", "defaultpass")).to eq("secret")
        expect_heard ["Enter the prompt ('none' for no value): |********| ", "******", ""]
      end

      it "should support 'none' password" do
        say "none"
        expect(subject.ask_for_password_or_none("prompt", "defaultpass")).to eq("")
        expect_heard ["Enter the prompt ('none' for no value): |********| ", "****", ""]
      end
    end
  end

  context "#ask_for_disk" do
    context "with nodisks" do
      before do
        allow(LinuxAdmin::Disk).to receive_messages(:local => [double(:partitions => [:partition])])
      end

      it "should be ok with not partitioning" do
        say %w(Y)
        expect(subject.ask_for_disk("database disk")).to be_nil
        expect_heard [
          "No partition found for database disk. You probably want to add an unpartitioned disk and try again.",
          "",
          "Are you sure you don't want to partion the database disk? (Y/N): ",
        ]
      end

      it "should raise an exception if dont put on root partition" do
        say %w(N)
        expect { subject.ask_for_disk("special disk") }.to raise_error(MiqSignalError)
        expect_heard [
          "No partition found for special disk. You probably want to add an unpartitioned disk and try again.",
          "",
          "Are you sure you don't want to partion the special disk? (Y/N): ",
        ]
      end

      it "can skip confirmation prompt" do
        expect(subject.ask_for_disk("database disk", false)).to be_nil
        expect_heard [
          "No partition found for database disk. You probably want to add an unpartitioned disk and try again.", ""
        ]
      end
    end

    context "with one disk" do
      before do
        allow(LinuxAdmin::Disk).to receive_messages(:local => double(:select => [first_disk]))
      end
      let(:first_disk)  { double(:path => "/dev/a", :size => 10.megabyte) }

      it "should default to the first disk" do
        say ""
        expect_cls
        expect(subject.ask_for_disk("database disk").path).to eq("/dev/a")
        expect_heard ["database disk", "", "",
                      "1) /dev/a: 10 MB", "",
                      "2) Don't partition the disk", "", "",
                      "Choose the database disk: |1| "]
      end
    end

    context "with disks" do
      before do
        allow(LinuxAdmin::Disk).to receive_messages(:local => double(:select => [first_disk, second_disk]))
      end

      let(:first_disk)  { double(:path => "/dev/a", :size => 10.megabyte) }
      let(:second_disk) { double(:path => "/dev/b", :size => 20.megabyte) }

      it "should choose the first disk" do
        say %w(x 1)
        expect_cls
        expect(subject.ask_for_disk("database disk").path).to eq("/dev/a")
        expect_heard ["database disk", "", "",
                      "1) /dev/a: 10 MB", "",
                      "2) /dev/b: 20 MB", "",
                      "3) Don't partition the disk", "", "",
                      "Choose the database disk: " \
                      "You must choose one of [1, 2, 3, /dev/a: 10 MB, /dev/b: 20 MB, Don't partition the disk].",
                      prompt]
      end
    end
  end

  context "#ask_with_menu" do
    it "should ask for a menu" do
      error = 'You must choose one of [1, 2, a, b].'
      say %w(5 1)
      expect_cls
      expect(subject.ask_with_menu("q?", %w(a b))).to eq("a")
      expect_heard ["q?", "", "",
                    "1) a", "",
                    "2) b", "", "",
                    "Choose the q?: #{error}", prompt]
    end

    it "should ask for a menu with a hash" do
      say %w(1)
      expect_cls
      expect(subject.ask_with_menu("q?", "a" => "a1", "b" => "b1")).to eq("a1")
      expect_heard ["q?", "", "", "1) a", "", "2) b", "", "", "Choose the q?: "]
    end

    it "default to the index of a menu array option" do
      say ""
      expect_cls
      expect(subject.ask_with_menu("q?", %w(a b), 1)).to eq("a")
      expect_heard ["q?", "", "", "1) a", "", "2) b", "", "", "Choose the q?: |1| "]
    end

    it "defaults to the number of a menu option" do
      say ""
      expect_cls
      expect(subject.ask_with_menu("q?", {"a" => "a1", "b" => "b1"}, 1)).to eq("a1")
      expect_heard ["q?", "", "", "1) a", "", "2) b", "", "", "Choose the q?: |1| "]
    end

    it "defaults to the index of a menu hash key option" do
      say ""
      expect_cls
      expect(subject.ask_with_menu("q?", {"a" => "a1", "b" => "b1"}, "a")).to eq("a1")
      expect_heard ["q?", "", "", "1) a", "", "2) b", "", "", "Choose the q?: |1| "]
    end

    it "defaults to the index of a menu hash value option" do
      say ""
      expect_cls
      expect(subject.ask_with_menu("q?", {"a" => "a1", "b" => "b1"}, "b1")).to eq("b1")
      expect_heard ["q?", "", "", "1) a", "", "2) b", "", "", "Choose the q?: |2| "]
    end
  end

  context "#ask_for_string" do
    it "should work without a default" do
      say "x"
      expect(subject.ask_for_string("prompt")).to eq("x")
      expect_heard("Enter the prompt: ")
    end

    it "provides defaults" do
      say ""
      expect(subject.ask_for_string("prompt", "default")).to eq("default")
      expect_heard("Enter the prompt: |default| ")
    end

    it "overrides defaults" do
      say "this"
      expect(subject.ask_for_string("prompt", "default")).to eq("this")
      expect_heard("Enter the prompt: |default| ")
    end
  end

  context "#ask_for_integer" do
    it "should ensure integer" do
      error = "Please provide an integer"
      say %w(a b 1)
      expect(subject.ask_for_integer("prompt")).to eq(1)
      expect_heard ["Enter the prompt: ", error, prompt + error, prompt]
    end

    it "should check range" do
      error = "Your answer isn't within the expected range (included in 1..10)."
      say %w(0 11 5)
      expect(subject.ask_for_integer("prompt", 1..10)).to eq(5)
      expect_heard ["Enter the prompt: ", error, prompt + error, prompt]
    end
  end

  context "#ask_yn?" do
    it "should respond to yes (and enforce y/n)" do
      error = "Please provide yes or no."
      say %w(x z yes)
      expect(subject.ask_yn?("prompt")).to be_truthy
      expect_heard ["prompt? (Y/N): ", error, prompt + error, prompt]
    end

    it "should respond to no" do
      say %w(n)
      expect(subject.ask_yn?("prompt")).not_to be_truthy
      expect_heard "prompt? (Y/N): "
    end

    it "should support the default true" do
      say ""
      expect(subject.ask_yn?("prompt", "Y")).to be_truthy
      expect_heard "prompt? (Y/N): |Y| "
    end

    it "should support the default false" do
      say ""
      expect(subject.ask_yn?("prompt", "N")).not_to be_truthy
      expect_heard "prompt? (Y/N): |N| "
    end

    it "should support overriding the default true" do
      say %w(no)
      expect(subject.ask_yn?("prompt", "Y")).not_to be_truthy
      expect_heard "prompt? (Y/N): |Y| "
    end

    it "should support overriding the default false" do
      say %w(yes)
      expect(subject.ask_yn?("prompt", "N")).to be_truthy
      expect_heard "prompt? (Y/N): |N| "
    end
  end

  describe "#ask_for_domain" do
    it "supports second-level domains" do
      say "example.com"
      expect(subject.ask_for_domain("prompt")).to eq("example.com")
    end

    it "supports top-level domains" do
      say "example"
      expect(subject.ask_for_domain("prompt")).to eq("example")
    end
  end

  context "#just_ask (private method)" do
    it "should work without a default" do
      say "x"
      expect(subject.just_ask("prompt")).to eq("x")
      expect_heard("Enter the prompt: ")
    end

    it "should accept a default" do
      say ""
      expect(subject.just_ask("prompt", "default")).to eq("default")
      expect_heard("Enter the prompt: |default| ")
    end

    it "should override a default" do
      say "this"
      expect(subject.just_ask("prompt", "default")).to eq("this")
      expect_heard("Enter the prompt: |default| ")
    end
  end

  private

  def say(strs)
    Array(strs).each do |str|
      input << str << "\n"
    end
    input.rewind
  end

  def expect_cls
    expect(subject).to receive(:print)
  end

  def expect_heard(strs, check_eof = true)
    strs = Array(strs).collect { |s| s == "" ? "\n" : s }.join

    expect(output.string).to eq(strs)
    expect { subject.ask("is there more") }.to raise_error(EOFError) if check_eof
    expect(input).to be_eof
  end
end

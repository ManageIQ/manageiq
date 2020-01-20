RSpec.describe PidFile do
  before do
    @fname = 'foo.bar'
    @pid_file = PidFile.new(@fname)
  end

  context "#pid" do
    it "returns nil when file does not exist" do
      allow(File).to receive(:file?).with(@fname).and_return(false)
      expect(@pid_file.pid).to be_nil
    end

    context "file does exist" do
      before do
        allow(File).to receive(:file?).with(@fname).and_return(true)
      end

      it "returns nil when file contents blank" do
        allow(IO).to receive(:read).with(@fname).and_return("  ")
        expect(@pid_file.pid).to be_nil
      end

      it "returns nil when file contents are non numeric" do
        allow(IO).to receive(:read).with(@fname).and_return("text")
        expect(@pid_file.pid).to be_nil
      end

      it "returns pid when file contents have pid" do
        pid = 42
        allow(IO).to receive(:read).with(@fname).and_return("#{pid} ")
        expect(@pid_file.pid).to eq(pid)
      end
    end
  end

  context "#remove" do
    it "noops when file does not exist" do
      allow(File).to receive(:file?).with(@fname).and_return(false)
      expect(FileUtils).to receive(:rm).with(@fname).never
      @pid_file.remove
    end

    it "deletes when file exist and is our process" do
      allow(@pid_file).to receive(:pid).and_return(Process.pid)
      expect(FileUtils).to receive(:rm).with(@fname).once
      @pid_file.remove
    end
  end

  context "#create" do
    it "creates file whose contents are Process.pid" do
      @dirname = "/test/dir"
      allow(File).to receive(:dirname).with(@fname).and_return(@dirname)
      expect(FileUtils).to receive(:mkdir_p).with(@dirname).once

      @fhandle = double('file_handle')
      expect(@fhandle).to receive(:write).with(Process.pid).once
      allow(File).to receive(:open).with(@fname, 'w').and_yield(@fhandle)

      @pid_file.create
    end
  end

  context "#running?" do
    it "returns false if #pid returns nil" do
      allow(@pid_file).to receive(:pid).and_return(nil)
      expect(@pid_file.running?).to be_falsey
    end

    context "#pid returns valid value" do
      before do
        @pid = 42
        allow(@pid_file).to receive(:pid).and_return(@pid)
      end

      it "returns false if MiqProcess.command_line returns nil" do
        allow(MiqProcess).to receive(:command_line).and_return(nil)
        expect(@pid_file.running?).to be_falsey
      end

      it "returns false if MiqProcess.command_line returns an empty string" do
        allow(MiqProcess).to receive(:command_line).and_return("")
        expect(@pid_file.running?).to be_falsey
      end

      context "MiqProcess.command_line returns valid value" do
        before do
          @cmd_line = "my favorite program"
          allow(MiqProcess).to receive(:command_line).and_return(@cmd_line)
        end

        it "returns true with no parms" do
          expect(@pid_file.running?).to be_truthy
        end

        it "returns true with valid Regexp" do
          expect(@pid_file.running?(/program/)).to be_truthy
        end

        it "returns true with valid Regexp as String" do
          expect(@pid_file.running?('program')).to be_truthy
        end

        it "returns false with invalid Regexp" do
          expect(@pid_file.running?(/programme/)).to be_falsey
        end

        it "returns false with invalid Regexp as String" do
          expect(@pid_file.running?('programme')).to be_falsey
        end
      end
    end
  end
end

require "spec_helper"

describe PidFile do

  before(:each) do
    @fname = 'foo.bar'
    @pid_file = PidFile.new(@fname)
  end

  context "#pid" do
    it "returns nil when file does not exist" do
      File.stub(:file?).with(@fname).and_return(false)
      @pid_file.pid.should be_nil
    end

    context "file does exist" do
      before(:each) do
        File.stub(:file?).with(@fname).and_return(true)
      end

      it "returns nil when file contents blank" do
        IO.stub(:read).with(@fname).and_return("  ")
        @pid_file.pid.should be_nil
      end

      it "returns pid when file contents have pid" do
        pid = 42
        IO.stub(:read).with(@fname).and_return("#{pid} ")
        @pid_file.pid.should == pid
      end
    end
  end

  context "#remove" do
    it "noops when file does not exist" do
      File.stub(:file?).with(@fname).and_return(false)
      FileUtils.should_receive(:rm).with(@fname).never
      @pid_file.remove
    end

    it "deletes when file does exist" do
      File.stub(:file?).with(@fname).and_return(true)
      FileUtils.should_receive(:rm).with(@fname).once
      @pid_file.remove
    end
  end

  context "#create" do
    it "creates file whose contents are Process.pid" do
      @dirname = "/test/dir"
      File.stub(:dirname).with(@fname).and_return(@dirname)
      FileUtils.should_receive(:mkdir_p).with(@dirname).once

      @fhandle = double('file_handle')
      @fhandle.should_receive(:write).with(Process.pid).once
      File.stub(:open).with(@fname, 'w').and_yield(@fhandle)

      @pid_file.create
    end
  end

  context "#running?" do
    it "returns false if #pid returns nil" do
      @pid_file.stub(:pid).and_return(nil)
      @pid_file.running?.should be_false
    end

    context "#pid returns valid value" do
      before(:each) do
        @pid = 42
        @pid_file.stub(:pid).and_return(@pid)
      end

      it "returns false if MiqProcess.command_line returns nil" do
        MiqProcess.stub(:command_line).and_return(nil)
        @pid_file.running?.should be_false
      end

      context "MiqProcess.command_line returns valid value" do
        before(:each) do
          @cmd_line = "my favorite program"
          MiqProcess.stub(:command_line).and_return(@cmd_line)
        end

        it "returns true with no parms" do
          @pid_file.running?.should be_true
        end

        it "returns true with valid Regexp" do
          @pid_file.running?(/program/).should be_true
        end

        it "returns true with valid Regexp as String" do
          @pid_file.running?('program').should be_true
        end

        it "returns false with invalid Regexp" do
          @pid_file.running?(/programme/).should be_false
        end

        it "returns false with invalid Regexp as String" do
          @pid_file.running?('programme').should be_false
        end

      end

    end

  end


end

require "spec_helper"

describe Vmdb::Logging::MirroredLogger do
  before(:each) do
    @mirror_stream = StringIO.new
    @log_stream = StringIO.new
    @log = Vmdb::Logging::MirroredLogger.new(@log_stream, "<MirrorPrefix> ")
    @log.mirror_logger = VMDBLogger.new(@mirror_stream)
  end

  {
    :debug => { :debug => true,  :info => true,  :warn => true,  :error => true,  :fatal => true },
    :info  => { :debug => false, :info => true,  :warn => true,  :error => true,  :fatal => true },
    :warn  => { :debug => false, :info => false, :warn => true,  :error => true,  :fatal => true },
    :error => { :debug => false, :info => false, :warn => false, :error => true,  :fatal => true },
    :fatal => { :debug => false, :info => false, :warn => false, :error => false, :fatal => true }
  }.each do |mirror_level, cases|
    context "with mirror level set to #{mirror_level.to_s.upcase}" do
      before(:each) do
        @log.mirror_level = VMDBLogger.const_get(mirror_level.to_s.upcase)

        # Set test logs to DEBUG, so no messages are supressed except by the mirror_level
        @log.level = @log.mirror_logger.level = VMDBLogger::DEBUG
      end

      cases.each do |level, mirrored|
        it "##{level}" do
          @log.send(level, "Testing!")

          @log_stream.rewind
          lines = @log_stream.lines.to_a
          lines.length.should == 1
          line = lines.first.chomp
          line[7, 1].should == level.to_s[0, 1].upcase
          line[-13..-1].should == "-- : Testing!"

          @mirror_stream.rewind
          lines = @mirror_stream.lines.to_a
          if mirrored
            lines.length.should == 1
            line = lines.first.chomp
            line[7, 1].should == level.to_s[0, 1].upcase
            line[-28..-1].should == "-- : <MirrorPrefix> Testing!"
          else
            lines.length.should == 0
          end
        end

        it "#mirror?(#{level.to_s.upcase})" do
          @log.mirror?(VMDBLogger.const_get(level.to_s.upcase)).should == mirrored
        end
      end
    end
  end
end

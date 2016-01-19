describe Vmdb::Loggers::MirroredLogger do
  before(:each) do
    @mirror_stream = StringIO.new
    @log_stream = StringIO.new
    @log = Vmdb::Loggers::MirroredLogger.new(@log_stream, "<MirrorPrefix> ")
    @log.mirror_logger = VMDBLogger.new(@mirror_stream)
  end

  {
    :debug => {:debug => true,  :info => true,  :warn => true,  :error => true,  :fatal => true},
    :info  => {:debug => false, :info => true,  :warn => true,  :error => true,  :fatal => true},
    :warn  => {:debug => false, :info => false, :warn => true,  :error => true,  :fatal => true},
    :error => {:debug => false, :info => false, :warn => false, :error => true,  :fatal => true},
    :fatal => {:debug => false, :info => false, :warn => false, :error => false, :fatal => true}
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
          lines = @log_stream.each_line.to_a
          expect(lines.length).to eq(1)
          line = lines.first.chomp
          expect(line[7, 1]).to eq(level.to_s[0, 1].upcase)
          expect(line[-13..-1]).to eq("-- : Testing!")

          @mirror_stream.rewind
          lines = @mirror_stream.each_line.to_a
          if mirrored
            expect(lines.length).to eq(1)
            line = lines.first.chomp
            expect(line[7, 1]).to eq(level.to_s[0, 1].upcase)
            expect(line[-28..-1]).to eq("-- : <MirrorPrefix> Testing!")
          else
            expect(lines.length).to eq(0)
          end
        end

        it "#mirror?(#{level.to_s.upcase})" do
          expect(@log.mirror?(VMDBLogger.const_get(level.to_s.upcase))).to eq(mirrored)
        end
      end
    end
  end
end

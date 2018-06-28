require 'tempfile'
require 'pathname'
require 'manageiq/util/file_splitter'

module ManageIQ::Util
  describe FileSplitter do
    shared_context "generated tmp files" do
      let!(:tmpfile_size) { 10.megabytes }
      let!(:source_path)  { Pathname.new(source_file.path) }
      let!(:source_file) do
        Tempfile.new("source_file").tap do |file|
          file.write("0" * tmpfile_size)
          file.close
        end
      end

      after do
        source_file.unlink
        Dir["#{source_path.expand_path}.*"].each do |file|
          File.delete(file)
        end
      end
    end

    describe ".run" do
      include_context "generated tmp files"

      it "splits a file by 10MB by default" do
        FileSplitter.run(:input_file => File.open(source_path))
        expected_splitfiles = [source_path.dirname.join("#{source_path.basename}.00001")]

        expected_splitfiles.each do |filename|
          expect(File.exist?(filename.to_s)).to be true
          expect(Pathname.new(filename).lstat.size).to eq(10.megabyte)
        end
      end

      it "splits a file by 1MB when specified" do
        FileSplitter.run(:byte_count => 1.megabyte, :input_file => File.open(source_path))
        expected_splitfiles = (1..10).map do |suffix|
          source_path.dirname.join("#{source_path.basename}.000#{'%02d' % suffix}")
        end

        expected_splitfiles.each do |filename|
          expect(File.exist?(filename.to_s)).to be true
          expect(Pathname.new(filename).lstat.size).to eq(1.megabyte)
        end
      end

      it "can take args from ARGV" do
        stub_const("ARGV", ["--b", 1.megabyte.to_s, source_path])
        FileSplitter.run
        expected_splitfiles = (1..10).map do |suffix|
          source_path.dirname.join("#{source_path.basename}.000#{'%02d' % suffix}")
        end

        expected_splitfiles.each do |filename|
          expect(File.exist?(filename.to_s)).to be true
          expect(Pathname.new(filename).lstat.size).to eq(1.megabyte)
        end
      end
    end

    describe ".parse_argv" do
      context "with no args" do
        before { stub_const("ARGV", []) }

        it "raises an error" do
          expect { FileSplitter.parse_argv }.to raise_error(ArgumentError)
        end
      end

      context "with a source filename" do
        include_context "generated tmp files"
        before { stub_const("ARGV", [source_path.to_s]) }

        it "sets :input_file to a file object from the filename" do
          expected = FileSplitter.parse_argv[:input_file]
          actual   = File.new(source_path.expand_path)
          expect(FileUtils.compare_stream(expected, actual)).to be true
        end

        it "does not set byte_count" do
          expect(FileSplitter.parse_argv[:byte_count]).to be nil
        end
      end

      context "with the source file equaling -" do
        before { stub_const("ARGV", ["-", "my_pattern"]) }

        it "sets :input_file to nil" do
          expect(FileSplitter.parse_argv[:input_file]).to eq(nil)
        end

        it "sets :input_filename to 'my_pattern'" do
          expect(FileSplitter.parse_argv[:input_filename]).to eq('my_pattern')
        end

        it "does not set byte_count" do
          expect(FileSplitter.parse_argv[:byte_count]).to be nil
        end
      end

      context "with --byte-count passed in as '1048576' (1 megabyte)" do
        before { stub_const("ARGV", ["--byte-count", 1.megabyte.to_s, 'my_pattern']) }

        it "sets :input_file to nil" do
          expect(FileSplitter.parse_argv[:input_file]).to eq(nil)
        end

        it "sets :input_filename to 'my_pattern'" do
          expect(FileSplitter.parse_argv[:input_filename]).to eq('my_pattern')
        end

        it "set byte_count to 1,048,576" do
          expect(FileSplitter.parse_argv[:byte_count]).to eq(1_048_576)
        end
      end

      context "with -b passed in as '1M' (1 megabyte)" do
        before { stub_const("ARGV", ["-b", "1M", 'my_pattern']) }

        it "sets :input_file to nil" do
          expect(FileSplitter.parse_argv[:input_file]).to eq(nil)
        end

        it "sets :input_filename to 'my_pattern'" do
          expect(FileSplitter.parse_argv[:input_filename]).to eq('my_pattern')
        end

        it "set byte_count to 1,048,576" do
          expect(FileSplitter.parse_argv[:byte_count]).to eq(1_048_576)
        end
      end

      context "with -b passed in as '1k' (1 kilobyte)" do
        before { stub_const("ARGV", ["-b", "1k", "my_pattern"]) }

        it "sets :input_file to nil" do
          expect(FileSplitter.parse_argv[:input_file]).to eq(nil)
        end

        it "set byte_count to 1048576" do
          expect(FileSplitter.parse_argv[:byte_count]).to eq(1024)
        end
      end
    end

    describe "running as a command" do
      include_context "generated tmp files"

      let(:script_file) { Rails.root.join("lib", "manageiq", "util", "file_splitter.rb") }

      it "can pipe output from another command" do
        `cat #{source_path.expand_path} | #{script_file} -b 2M - #{source_path.expand_path}`
        expected_splitfiles = (1..5).map do |suffix|
          source_path.dirname.join("#{source_path.basename}.0000#{suffix}")
        end

        expected_splitfiles.each do |filename|
          expect(File.exist?(filename.to_s)).to be true
          expect(Pathname.new(filename).lstat.size).to eq(2.megabyte)
        end
      end

      it "auto determines using a pipe if input file doesn't exist" do
        # NOTE: ommited the '-' in the cmd
        `cat #{source_path.expand_path} | #{script_file} -b 2M #{source_path.dirname.join('pattern')}`
        expected_splitfiles = (1..5).map do |suffix|
          source_path.dirname.join("pattern.0000#{suffix}")
        end

        expected_splitfiles.each do |filename|
          expect(File.exist?(filename.to_s)).to be true
          expect(Pathname.new(filename).lstat.size).to eq(2.megabyte)
        end
      end
    end
  end
end

require 'tempfile'
require 'pathname'
require 'manageiq/util/file_splitter'

# Putting this here since this config option can die with this script, and
# doesn't need to live in the global config.
RSpec.configure do |config|
  # These are tests that shouldn't run on CI, but should be semi-automated to
  # be triggered manaually to test in an automated fasion.  There will be setup
  # steps with a vagrant file to spinup a endpoint to use for this.
  #
  # TODO:  Maybe we should just use VCR for this?  Still would required the
  # vagrant VM I guess to record the tests from... so for now, skipping.
  config.filter_run_excluding :with_real_ftp => true
end

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

    shared_context "ftp context" do
      let(:ftp) do
        Net::FTP.new(URI(ftp_host).hostname).tap do |ftp|
          ftp.login(ftp_creds[:ftp_user], ftp_creds[:ftp_pass])
        end
      end

      let(:ftp_dir)    { File.join("", "uploads") }
      let(:ftp_host)   { ENV["FTP_HOST_FOR_SPECS"] || "ftp://192.168.50.3" }
      let(:ftp_creds)  { { :ftp_user => "anonymous", :ftp_pass => nil } }
      let(:ftp_config) { { :ftp_host => ftp_host, :ftp_dir => ftp_dir } }

      let(:ftp_user_1) { ENV["FTP_USER_1_FOR_SPECS"] || "vagrant" }
      let(:ftp_pass_1) { ENV["FTP_USER_1_FOR_SPECS"] || "vagrant" }

      let(:ftp_user_2) { ENV["FTP_USER_2_FOR_SPECS"] || "foo" }
      let(:ftp_pass_2) { ENV["FTP_USER_2_FOR_SPECS"] || "bar" }
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

      context "to an ftp target", :with_real_ftp => true do
        include_context "ftp context"

        let(:base_config) { { :byte_count => 1.megabyte, :input_file => File.open(source_path) } }
        let(:run_config)  { ftp_config.merge(base_config) }

        let(:expected_splitfiles) do
          (1..10).map do |suffix|
            File.join(ftp_dir, "#{source_path.basename}.000#{'%02d' % suffix}")
          end
        end

        it "uploads the split files as an annoymous user by default" do
          FileSplitter.run(run_config)

          expected_splitfiles.each do |filename|
            expect(ftp.nlst(filename)).to eq([filename])
            expect(ftp.size(filename)).to eq(1.megabyte)
            ftp.delete(filename)
          end
        end

        context "with slightly a slightly smaller input file than 10MB" do
          let(:tmpfile_size) { 10.megabytes - 1.kilobyte }

          it "properly chunks the file" do
            FileSplitter.run(run_config)

            expected_splitfiles[0, 9].each do |filename|
              expect(ftp.nlst(filename)).to eq([filename])
              expect(ftp.size(filename)).to eq(1.megabyte)
              ftp.delete(filename)
            end

            expect(ftp.nlst(expected_splitfiles.last)).to eq([expected_splitfiles.last])
            expect(ftp.size(expected_splitfiles.last)).to eq(1.megabyte - 1.kilobyte)
            ftp.delete(expected_splitfiles.last)
          end
        end

        context "with slightly a slightly larger input file than 10MB" do
          let(:tmpfile_size) { 10.megabytes + 1.kilobyte }

          it "properly chunks the file" do
            FileSplitter.run(run_config)

            expected_splitfiles.each do |filename|
              expect(ftp.nlst(filename)).to eq([filename])
              expect(ftp.size(filename)).to eq(1.megabyte)
              ftp.delete(filename)
            end

            filename = File.join(ftp_dir, "#{source_path.basename}.00011")
            expect(ftp.nlst(filename)).to eq([filename])
            expect(ftp.size(filename)).to eq(1.kilobyte)
            ftp.delete(filename)
          end
        end

        context "with a dir that doesn't exist" do
          let(:ftp_dir) { File.join("", "uploads", "backups", "current") }

          it "uploads the split files" do
            FileSplitter.run(run_config)

            expected_splitfiles.each do |filename|
              expect(ftp.nlst(filename)).to eq([filename])
              expect(ftp.size(filename)).to eq(1.megabyte)
              ftp.delete(filename)
            end
            ftp.rmdir(ftp_dir)
          end
        end

        context "with a specified user" do
          let(:ftp_dir)    { File.join("", "home", ftp_user_1) }
          let(:ftp_creds)  { { :ftp_user => ftp_user_1, :ftp_pass => ftp_pass_1 } }
          let(:run_config) { ftp_config.merge(ftp_creds).merge(base_config) }

          it "uploads the split files" do
            FileSplitter.run(run_config)

            expected_splitfiles.each do |filename|
              expect(ftp.nlst(filename)).to eq([filename])
              expect(ftp.size(filename)).to eq(1.megabyte)
              ftp.delete(filename)
            end
          end

          context "with a dir that doesn't exist" do
            let(:ftp_dir) { File.join("", "home", ftp_user_1, "backups") }

            it "uploads the split files" do
              FileSplitter.run(run_config)

              expected_splitfiles.each do |filename|
                expect(ftp.nlst(filename)).to eq([filename])
                expect(ftp.size(filename)).to eq(1.megabyte)
                ftp.delete(filename)
              end
              ftp.rmdir(ftp_dir)
            end
          end
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

      context "to a ftp target", :with_real_ftp => true do
        include_context "ftp context"

        let(:expected_splitfiles) do
          (1..5).map do |suffix|
            File.join(ftp_dir, "#{source_path.basename}.000#{'%02d' % suffix}")
          end
        end

        it "it uploads with an anonymous user by default" do
          cmd_opts = "-b 2M --ftp-host=#{ftp_host} --ftp-dir #{ftp_dir}"
          `cat #{source_path.expand_path} | #{script_file} #{cmd_opts} - #{source_path.basename}`

          expected_splitfiles.each do |filename|
            expect(ftp.nlst(filename)).to eq([filename])
            expect(ftp.size(filename)).to eq(2.megabyte)
            ftp.delete(filename)
          end
        end

        context "with a specified user via ENV vars" do
          let(:ftp_dir)    { File.join("", "home", ftp_user_1, "backups") }
          let(:ftp_creds)  { { :ftp_user => ftp_user_1, :ftp_pass => ftp_pass_1 } }
          let(:run_config) { ftp_config.merge(ftp_creds).merge(base_config) }

          it "uploads the split files and creates necessary dirs" do
            env      = { 'FTP_USERNAME' => ftp_user_1, 'FTP_PASSWORD' => ftp_pass_1 }
            cmd_opts = "-b 2M --ftp-host=#{ftp_host} --ftp-dir #{ftp_dir}"
            cmd      = "cat #{source_path.expand_path} | #{script_file} #{cmd_opts} - #{source_path.basename}"
            pid      = Kernel.spawn(env, cmd)
            Process.wait(pid)

            expect($CHILD_STATUS).to eq(0)
            expected_splitfiles.each do |filename|
              expect(ftp.nlst(filename)).to eq([filename])
              expect(ftp.size(filename)).to eq(2.megabyte)
              ftp.delete(filename)
            end
            ftp.rmdir(ftp_dir)
          end
        end
      end
    end
  end
end

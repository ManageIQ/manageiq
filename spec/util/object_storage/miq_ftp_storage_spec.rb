require 'util/object_storage/miq_ftp_storage.rb'

describe MiqFtpStorage, :with_ftp_server do
  subject         { described_class.new(ftp_creds.merge(:uri => "ftp://localhost")) }
  let(:ftp_creds) { { :username => "ftpuser", :password => "ftppass" } }

  describe "#add" do
    include_context "generated tmp files"

    shared_examples "adding files" do |dest_path|
      let(:dest_path) { dest_path }

      it "copies single files" do
        expect(subject.add(source_path.to_s, dest_path.to_s)).to eq(dest_path.to_s)
        expect(dest_path).to exist_on_ftp_server
        expect(dest_path).to have_size_on_ftp_server_of(10.megabytes)
      end

      it "copies file to splits" do
        expected_splitfiles = (1..5).map do |suffix|
          "#{dest_path}.0000#{suffix}"
        end

        File.open(source_path) do |f| # with an IO object this time
          subject.add(f, dest_path.to_s, "2M")
        end

        expected_splitfiles.each do |filename|
          expect(filename).to exist_on_ftp_server
          expect(filename).to have_size_on_ftp_server_of(2.megabytes)
        end
      end

      it "can take input from a command" do
        expected_splitfiles = (1..5).map do |suffix|
          "#{dest_path}.0000#{suffix}"
        end

        subject.add(dest_path.to_s, "2M") do |input_writer|
          `#{Gem.ruby} -e "File.write('#{input_writer}', '0' * #{tmpfile_size})"`
        end

        expected_splitfiles.each do |filename|
          expect(filename).to exist_on_ftp_server
          expect(filename).to have_size_on_ftp_server_of(2.megabytes)
        end
      end

      context "with slightly a slightly smaller input file than 10MB" do
        let(:tmpfile_size) { 10.megabytes - 1.kilobyte }

        it "properly chunks the file" do
          expected_splitfiles = (1..10).map do |suffix|
            "#{dest_path}.%<suffix>05d" % {:suffix => suffix}
          end

          # using pathnames this time
          subject.add(source_path, dest_path.to_s, 1.megabyte)

          expected_splitfiles[0, 9].each do |filename|
            expect(filename).to exist_on_ftp_server
            expect(filename).to have_size_on_ftp_server_of(1.megabytes)
          end

          last_split = expected_splitfiles.last
          expect(last_split).to exist_on_ftp_server
          expect(last_split).to have_size_on_ftp_server_of(1.megabyte - 1.kilobyte)
        end
      end
    end

    context "using a 'relative path'" do
      include_examples "adding files", "path/to/file"
    end

    context "using a 'absolute path'" do
      include_examples "adding files", "/path/to/my_file"
    end

    context "using a uri" do
      include_examples "adding files", "ftp://localhost/foo/bar/baz"
    end
  end

  describe "#download" do
    let(:dest_path)   { Dir::Tmpname.create("") { |name| name } }
    let(:source_file) { existing_ftp_file(10.megabytes) }
    let(:source_path) { File.basename(source_file.path) }

    after { File.delete(dest_path) if File.exist?(dest_path) }

    it "downloads the file" do
      subject.download(dest_path, source_path)

      # Sanity check that what we are downloading is the size we expect
      expect(source_path).to exist_on_ftp_server
      expect(source_path).to have_size_on_ftp_server_of(10.megabytes)

      expect(File.exist?(dest_path)).to be true
      expect(File.stat(dest_path).size).to eq(10.megabytes)
    end

    it "can take input from a command" do
      source_data = nil
      subject.download(nil, source_path) do |input_writer|
        source_data = `#{Gem.ruby} -e "print File.read('#{input_writer}')"`
      end

      # Sanity check that what we are downloading is the size we expect
      # (and we didn't actually download the file to disk)
      expect(File.exist?(dest_path)).to be false
      expect(source_path).to exist_on_ftp_server
      expect(source_path).to have_size_on_ftp_server_of(10.megabytes)

      # Nothing written, just printed the streamed file in the above command
      expect(source_data.size).to eq(10.megabytes)
    end
  end
end

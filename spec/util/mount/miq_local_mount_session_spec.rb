require 'util/mount/miq_local_mount_session'
require 'tempfile'

describe MiqLocalMountSession do
  shared_context "generated tmp files" do
    let!(:tmpfile_size) { 10.megabytes }
    let!(:source_path)  { Pathname.new(source_file.path) }
    let!(:source_file) do
      Tempfile.new("source_file").tap do |file|
        file.write("0" * tmpfile_size)
        file.close
      end
    end
    let!(:dest_path) do
      Pathname.new(Dir::Tmpname.create("") {})
    end

    after do
      source_file.unlink
      Dir["#{source_path.expand_path}.*"].each do |file|
        File.delete(file)
      end
    end
  end

  subject { described_class.new(:uri => "file://") }

  describe "#add" do
    include_context "generated tmp files"

    it "copies single files" do
      expect(subject.add(source_path.to_s, dest_path.to_s)).to eq(dest_path.to_s)
      expect(File.exist?(dest_path)).to be true
      expect(Pathname.new(dest_path).lstat.size).to eq(10.megabytes)
    end

    it "copies file to splits" do
      expected_splitfiles = (1..5).map do |suffix|
        source_path.dirname.join("#{dest_path.basename}.0000#{suffix}")
      end

      File.open(source_path) do |f| # with an IO object this time
        subject.add(f, dest_path.to_s, "2M")
      end

      expected_splitfiles.each do |filename|
        expect(File.exist?(filename)).to be true
        expect(Pathname.new(filename).lstat.size).to eq(2.megabytes)
      end
    end

    it "can take input from a command" do
      expected_splitfiles = (1..5).map do |suffix|
        source_path.dirname.join("#{dest_path.basename}.0000#{suffix}")
      end

      subject.add(dest_path.to_s, "2M") do |input_writer|
        `#{Gem.ruby} -e "File.write('#{input_writer}', '0' * #{tmpfile_size})"`
      end

      expected_splitfiles.each do |filename|
        expect(File.exist?(filename)).to be true
        expect(Pathname.new(filename).lstat.size).to eq(2.megabytes)
      end
    end

    context "with a slightly smaller input file than 10MB" do
      let(:tmpfile_size) { 10.megabytes - 1.kilobyte }

      it "properly chunks the file" do
        expected_splitfiles = (1..10).map do |suffix|
          name = "#{dest_path.basename}.%<suffix>05d" % {:suffix => suffix}
          source_path.dirname.join(name)
        end

        # using pathnames this time
        subject.add(source_path, dest_path.to_s, 1.megabyte)

        expected_splitfiles[0, 9].each do |filename|
          expect(File.exist?(filename)).to be true
          expect(Pathname.new(filename).lstat.size).to eq(1.megabyte)
        end

        last_split = expected_splitfiles.last
        expect(File.exist?(last_split)).to be true
        expect(Pathname.new(last_split).lstat.size).to eq(1.megabyte - 1.kilobyte)
      end
    end
  end

  describe "#download" do
    include_context "generated tmp files"

    it "downloads the file" do
      subject.download(dest_path.to_s, source_path.to_s)
      expect(File.exist?(dest_path)).to be true
      expect(Pathname.new(dest_path).lstat.size).to eq(10.megabytes)
    end

    it "can take input from a command" do
      source_data = nil
      subject.download(nil, source_path) do |input_writer|
        source_data = `#{Gem.ruby} -e "print File.read('#{input_writer}')"`
      end

      expect(File.exist?(dest_path)).to be false
      expect(source_data.size).to eq(10.megabytes)
      expect(source_data).to eq(File.read(source_path))
    end
  end
end

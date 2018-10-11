require "fileutils"
require "util/mount/miq_generic_mount_session"
require "util/miq_object_storage"

class MockLocalFileStorage < MiqObjectStorage
  def initialize source_path = nil, byte_count = 2.megabytes
    @byte_count   = byte_count
    @source_input = File.open(source_path, "rb") if source_path
    @root_dir     = Dir.tmpdir
  end

  def mkdir(dir)
    FileUtils.mkdir_p(File.join(@root_dir, dir))
  end
end

describe MiqObjectStorage do
  describe "#write_single_split_file_for (private)" do
    include_context "generated tmp files"

    subject         { MockLocalFileStorage.new source_path }
    let(:dest_path) { Dir::Tmpname.create("") { |name| name } }

    it "copies file to splits" do
      expected_splitfiles = (1..5).map do |suffix|
        "#{dest_path}.0000#{suffix}"
      end

      expected_splitfiles.each do |file|
        subject.send(:write_single_split_file_for, File.open(file, "wb"))
      end

      expected_splitfiles.each do |filename|
        expect(File.exist?(filename)).to be true
        expect(Pathname.new(filename).lstat.size).to eq(2.megabytes)
      end
    end

    context "with slightly a slightly smaller input file than 10MB" do
      let(:tmpfile_size) { 10.megabytes - 1.kilobyte }
      subject            { MockLocalFileStorage.new source_path, 1.megabyte }

      it "properly chunks the file" do
        expected_splitfiles = (1..10).map do |suffix|
          "#{dest_path}.%<suffix>05d" % {:suffix => suffix}
        end

        expected_splitfiles.each do |file|
          subject.send(:write_single_split_file_for, File.open(file, "wb"))
        end

        expected_splitfiles[0, 9].each do |filename|
          expect(File.exist?(filename)).to be true
          expect(File.size(filename)).to eq(1.megabytes)
        end

        last_split = expected_splitfiles.last
        expect(File.exist?(last_split)).to be true
        expect(File.size(last_split)).to eq(1.megabyte - 1.kilobyte)
      end
    end

    context "non-split files (byte_count == nil)" do
      subject          { MockLocalFileStorage.new source_path, byte_count }

      let(:byte_count) { nil }

      it "streams the whole file over" do
        subject.send(:write_single_split_file_for, File.open(dest_path, "wb"))
        expect(File.exist?(dest_path)).to be true
        expect(Pathname.new(dest_path).lstat.size).to eq(tmpfile_size)
      end
    end
  end

  describe "#read_single_chunk (private)" do
    include_context "generated tmp files"

    subject         { MockLocalFileStorage.new source_path }
    let(:dest_path) { Dir::Tmpname.create("") { |name| name } }
    let(:chunksize) { MockLocalFileStorage::DEFAULT_CHUNKSIZE }

    it "reads 16384 by default" do
      chunk_of_data = subject.send(:read_single_chunk)
      expect(chunk_of_data).to eq("0" * chunksize)
    end

    it "reads the amount of data equal to chunksize when that is passed" do
      chunk_of_data = subject.send(:read_single_chunk, 1.kilobyte)
      expect(chunk_of_data).to eq("0" * 1.kilobyte)
    end

    context "near the end of the split file" do
      let(:data_left)            { 123 }
      let(:penultimate_chunkize) { chunksize - data_left }

      before do
        # read an odd amount of data
        read_times = 2.megabytes / chunksize
        (read_times - 1).times { subject.send(:read_single_chunk) }
        subject.send(:read_single_chunk, penultimate_chunkize)
      end

      it "reads only what is necessary to finish the split file" do
        chunk_of_data = subject.send(:read_single_chunk)
        expect(chunk_of_data).to eq("0" * data_left)
      end

      it "stops reading until `#clear_split_vars` is called" do
        expect(subject.send(:read_single_chunk)).to eq("0" * data_left)
        expect(subject.send(:read_single_chunk)).to eq("")
        expect(subject.send(:read_single_chunk)).to eq("")
        expect(subject.send(:read_single_chunk)).to eq("")

        subject.send(:clear_split_vars)

        expect(subject.send(:read_single_chunk)).to eq("0" * chunksize)
      end
    end
  end
end

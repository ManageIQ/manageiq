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

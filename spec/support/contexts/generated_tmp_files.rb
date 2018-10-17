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
    # When source_file.unlink is called, it will make it so `source_file.path`
    # returns `nil`.  Cache it's value incase it hasn't been accessed in the
    # tests so we can clear out the generated files properly.
    tmp_source_path = source_path

    source_file.unlink
    Dir["#{tmp_source_path.expand_path}.*"].each do |file|
      File.delete(file)
    end

    if defined?(dest_path) && dest_path.to_s.include?(Dir.tmpdir)
      Dir["#{dest_path}*"].each do |file|
        File.delete(file)
      end
    end
  end
end

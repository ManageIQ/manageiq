RSpec.describe TaskHelpers::Exports do
  describe '.safe_filename' do
    it 'should return a filename without spaces' do
      filename = TaskHelpers::Exports.safe_filename('filename without spaces')
      expect(filename).to eq('filename_without_spaces')
    end

    it 'should return a filename with spaces' do
      filename = TaskHelpers::Exports.safe_filename('filename without spaces', true)
      expect(filename).to eq('filename without spaces')
    end

    it 'should return a filename without / or spaces' do
      filename = TaskHelpers::Exports.safe_filename('filename with / removed')
      expect(filename).to eq('filename_with_slash_removed')
    end

    it 'should return a filename without / and with spaces' do
      filename = TaskHelpers::Exports.safe_filename('filename with / removed', true)
      expect(filename).to eq('filename with slash removed')
    end

    it 'should return a filename without | or spaces' do
      filename = TaskHelpers::Exports.safe_filename('filename with | removed')
      expect(filename).to eq('filename_with_pipe_removed')
    end

    it 'should return a filename without | and with spaces' do
      filename = TaskHelpers::Exports.safe_filename('filename with | removed', true)
      expect(filename).to eq('filename with pipe removed')
    end

    it 'should return a filename without /,  | or spaces' do
      filename = TaskHelpers::Exports.safe_filename('filename with / and | removed')
      expect(filename).to eq('filename_with_slash_and_pipe_removed')
    end

    it 'should not create duplicate filenames' do
      filename1 = TaskHelpers::Exports.safe_filename('filename with / removed')
      filename2 = TaskHelpers::Exports.safe_filename('filename with | removed')
      expect(filename1).not_to eq(filename2)
    end
  end

  describe '.validate_directory' do
    let(:export_dir2) { Dir.tmpdir + "/thisdoesntexist" }

    before do
      @export_dir = Dir.mktmpdir('miq_exp_dir')
    end

    after do
      FileUtils.remove_entry @export_dir
    end

    it 'is a directory and writable' do
      expect(TaskHelpers::Exports.validate_directory(@export_dir)).to be_nil
    end

    it 'does not exist' do
      expect(TaskHelpers::Exports.validate_directory(export_dir2)).to eq('Destination directory must exist')
    end

    it 'is not writable' do
      File.chmod(0o500, @export_dir)
      expect(TaskHelpers::Exports.validate_directory(@export_dir)).to eq('Destination directory must be writable')
    end
  end

  describe '.exclude_attributes' do
    let(:all_attributes) do
      { "id"         => 1,
        "name"       => "EvmRole-super_administrator",
        "read_only"  => true,
        "created_at" => Time.zone.now,
        "updated_at" => Time.zone.now,
        "settings"   => nil }
    end

    it 'removes selected attributes' do
      filtered_attributes = TaskHelpers::Exports.exclude_attributes(all_attributes, %w(created_at updated_at id))
      expect(filtered_attributes).to match("name" => "EvmRole-super_administrator", "read_only" => true, "settings" => nil)
    end
  end
end

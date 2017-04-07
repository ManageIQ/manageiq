describe TaskHelpers::Exports do
  context 'with filename' do
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
end

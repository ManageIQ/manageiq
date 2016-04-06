require_migration

describe AddHiddenToEmsFolders do
  migration_context :up do
    let(:ems_folder_stub) { migration_stub(:EmsFolder) }
    it 'sets EmsFolder.hidden to false' do
      folder = ems_folder_stub.create!

      migrate

      folder.reload
      expect(folder.hidden).to be false
    end
  end
end

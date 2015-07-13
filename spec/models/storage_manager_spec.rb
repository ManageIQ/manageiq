require "spec_helper"

describe StorageManager do

  it ".storage_manager_types" do
    expected_hash = { "NetappRemoteService" => "NetApp Remote Service" }
    expect(StorageManager.storage_manager_types).to eq(expected_hash)
  end

end

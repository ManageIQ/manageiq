require "spec_helper"
require "routing/shared_examples"

describe StorageManagerController do
  let(:controller_name) { "storage_manager" }

  it_behaves_like "A controller that has advanced search routes"
  it_behaves_like "A controller that has column width routes"
  it_behaves_like "A controller that has show list routes"
  it_behaves_like "A controller that has download_data routes"
  it_behaves_like "A controller that has CRUD routes"

end

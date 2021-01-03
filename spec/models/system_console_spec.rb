RSpec.describe SystemConsole do
  it "doesn't access database when unchanged model is saved" do
    m = described_class.create
    expect { m.valid? }.not_to make_database_queries
  end
end

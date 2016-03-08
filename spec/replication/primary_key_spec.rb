describe "all tables" do
  let(:connection) { ApplicationRecord.connection }

  it "have a primary key" do
    no_pk = []
    connection.tables.each do |t|
      next if t == "schema_migrations"
      no_pk << t unless connection.primary_key?(t)
    end
    expect(no_pk.size).to eq(0), "No primary key found for: #{no_pk.join(", ")}"
  end
end

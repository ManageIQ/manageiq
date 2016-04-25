describe "all tables" do
  let(:connection) { ApplicationRecord.connection }

  it "have a primary key called id" do
    no_pk = []
    connection.tables.each do |t|
      next if %w(schema_migrations ar_internal_metadata).include?(t)
      no_pk << t unless connection.primary_keys(t) == ["id"]
    end
    expect(no_pk.size).to eq(0), <<-EOS.gsub!(/^ +/, "")
      Primary key "id" not found for the following table(s):

      #{no_pk.join("\n")}

      All tables must have a primary key called "id"
      Replication with pglogical requires all tables to have a primary key
      We have chosen to use "id" rather than a composite key to avoid future migration
      problems should a table need to move away from a composite key in the future.
    EOS
  end
end

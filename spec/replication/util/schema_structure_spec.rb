describe "database schema" do
  it "is structured as expected" do
    ret = EvmDatabase.check_schema

    expect(ret).to be_nil, <<-EOS.gsub!(/^ +/, "")
      #{Rails.configuration.database_configuration[Rails.env]["database"]} is not structured as expected.
      #{ret}
      Refer to http://talk.manageiq.org/t/new-schema-specs-for-new-replication/1404 for detail
    EOS
  end
end

describe "database schema" do
  def invalid_schema_message(message)
    <<-EOS.gsub!(/^ +/, "")
      #{Rails.configuration.database_configuration[Rails.env]["database"]} is not structured as expected.
      #{message}
      Refer to http://talk.manageiq.org/t/new-schema-specs-for-new-replication/1404 for detail
    EOS
  end

  it "is structured as expected" do
    message = EvmDatabase.check_schema

    expect(message).to be_nil, invalid_schema_message(message)
  end
end

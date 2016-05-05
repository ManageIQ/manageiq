describe "database schema" do
  it "is structured as expected" do
    ret = EvmDatabase.check_schema

    expect(ret).to be_nil, <<-EOS.gsub!(/^ +/, "")
      #{Rails.configuration.database_configuration[Rails.env]["database"]} is not structured as expected.

      #{ret}
    EOS
  end
end

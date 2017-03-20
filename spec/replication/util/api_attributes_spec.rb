describe "all tables" do
  let(:connection) { ApplicationRecord.connection }

  it "do not have an attribute called href" do
    href_tables = []
    connection.tables.each do |t|
      next if %w(schema_migrations ar_internal_metadata).include?(t)
      href_tables << t if connection.columns(t).collect(&:name).include?("href")
    end
    expect(href_tables.size).to eq(0), <<-EOS.gsub!(/^ +/, "")
      Attribute "href" was found for the following table(s):

      #{href_tables.join("\n")}

      The "href" attribute is reserved for the ManageIQ API.
    EOS
  end

  it "do not have an attribute called href_slug" do
    href_slug_tables = []
    connection.tables.each do |t|
      next if %w(schema_migrations ar_internal_metadata).include?(t)
      href_slug_tables << t if connection.columns(t).collect(&:name).include?("href_slug")
    end
    expect(href_slug_tables.size).to eq(0), <<-EOS.gsub!(/^ +/, "")
      Attribute "href_slug" was found for the following table(s):

      #{href_slug_tables.join("\n")}

      The "href_slug" attribute is reserved for ManageIQ API.
    EOS
  end
end

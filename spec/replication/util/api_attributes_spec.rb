describe "all tables" do
  let(:connection) { ApplicationRecord.connection }

  def api_invalid_tables_message(invalid_tables, attr)
    <<-EOS
Attribute "#{attr}" was found for the following tables(s):

#{invalid_tables.join("\n")}

The "#{attr}" attribute is reserved for the ManageIQ API.
EOS
  end

  it "do not have an attribute called href" do
    href_tables = connection.tables.select do |t|
      !%w(schema_migrations ar_internal_metadata).include?(t) && connection.columns(t).any? { |c| c.name == "href" }
    end
    expect(href_tables.size).to eq(0), api_invalid_tables_message(href_tables, "href")
  end

  it "do not have an attribute called href_slug" do
    href_slug_tables = connection.tables.select do |t|
      !%w(schema_migrations ar_internal_metadata).include?(t) && connection.columns(t).any? { |c| c.name == "href_slug" }
    end
    expect(href_slug_tables.size).to eq(0), api_invalid_tables_message(href_slug_tables, "href_slug")
  end
end

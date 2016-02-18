describe "all tables" do
  let(:connection) { ActiveRecord::Base.connection }

  it "have a primary key" do
    no_pk = []
    connection.tables.each do |t|
      next if t == "schema_migrations"
      no_pk << t unless primary_key?(t)
    end
    expect(no_pk.size).to eq(0), "No primary key found for: #{no_pk.join(", ")}"
  end

  def primary_key?(t)
    connection.select_value(<<-SQL)
      SELECT EXISTS(
        SELECT 1
        FROM pg_index
        WHERE indrelid = '#{t}'::regclass AND indisprimary = true
      )
    SQL
  end
end

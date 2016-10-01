describe "Database" do
  describe "foreign key constraints" do
    let(:query) do
      <<-SQL
        SELECT
          constraint_name, table_name
        FROM
          information_schema.table_constraints
        WHERE
          constraint_type = 'FOREIGN KEY'
      SQL
    end

    it "should not exist" do
      message = ""
      ActiveRecord::Base.connection.select_all(query).each do |fk|
        message << "Foreign key constraint #{fk["constraint_name"]} on table #{fk["table_name"]} should be removed\n"
      end
      raise message unless message.empty?
    end
  end

  describe "_id columns" do
    let(:query) do
      <<-SQL
        SELECT
          table_name, column_name, data_type
        FROM
          information_schema.columns
        WHERE
          column_name LIKE '%\\_id' AND
          table_schema = 'public' AND
          data_type != 'bigint'
      SQL
    end

    let(:whitelist) do
      YAML.load_file(File.join(__dir__, 'data/id_column_whitelist.yml'))
    end

    it "should be of type bigint" do
      message = ""
      ActiveRecord::Base.connection.select_all(query).each do |col|
        column_whitelist = whitelist[col["table_name"]]
        next if column_whitelist && column_whitelist.include?(col["column_name"])
        message << "Column #{col["column_name"]} in table #{col["table_name"]} is either named improperly (_id is reserved for actual id columns) or needs to be of type bigint\n"
      end
      raise message unless message.empty?
    end
  end
end

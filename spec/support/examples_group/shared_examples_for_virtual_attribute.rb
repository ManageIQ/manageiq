shared_examples_for "sql friendly virtual_attribute" do |v_col_name, expected_value|
  it "calculates attribute #{v_col_name} in ruby" do
    actual_record = subject.class.where(:id => subject.id).first
    expect(actual_record.send(v_col_name)).to eq(expected_value)
  end

  it "calculates attribute #{v_col_name} in sql" do
    # helping developers - attribute should be a sql friendly virtual attribute
    expect(subject.class.attribute_supported_by_sql?(v_col_name.to_sym)).to be_truthy

    # expect do
    actual_record = subject.class.where(:id => subject.id).select(:id, v_col_name.to_sym).order(v_col_name.to_sym).first
    # end.to make_database_queries(:count => 1)
    expect do
      expect(actual_record.send(v_col_name)).to eq(expected_value)
    end.not_to make_database_queries
  end
end

# not as cool as sql friendly, but includes gets our job done
shared_examples_for "queryless virtual_attribute" do |v_col_name, expected_value|
  it "calculates attribute #{v_col_name} in ruby" do
    actual_record = subject.class.where(:id => subject.id).first
    expect(actual_record.send(v_col_name)).to eq(expected_value)
  end

  it "calculates attribute #{v_col_name} including the associated records" do
    # if this is sql friendly, use sql friendly virtual attribute example
    expect(subject.class.attribute_supported_by_sql?(v_col_name.to_sym)).to be_falsey

    # expect do
    actual_record = subject.class.where(:id => rec.id).includes(v_col_name.to_sym).first
    # end.to make_database_queries(:count => 1)

    expect do
      expect(actual_record.send(v_col_name)).to eq(expected_value)
    end.not_to make_database_queries
  end
end

# well, it has ruby, so that is good
shared_examples_for "ruby only virtual_attribute" do |v_col_name, expected_value|
  it "calculates attribute #{v_col_name} in ruby" do
    # if this is sql friendly, use sql friendly virtual attribute example
    expect(subject.class.attribute_supported_by_sql?(v_col_name.to_sym)).to be_falsey

    actual_record = subject.class.where(:id => subject.id).first
    expect(actual_record.send(v_col_name)).to eq(expected_value)
  end
end

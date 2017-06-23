require_migration

describe CleanUpDuplicatesInContainersTables do
  def model_unique_keys(model)
    models[model]
  end

  def models
    described_class::UNIQUE_INDEXES_FOR_MODELS
  end

  def model_stub(model)
    migration_stub(model.to_s.to_sym)
  end

  def create_test_data(model)
    build_data(model, 10, "string_1")
    build_data(model, 10, "string_1")
    build_data(model, 10, "string_2")
    build_data(model, 11, "string_1")
    build_data(model, 11, "string_1")
    build_data(model, 11, "string_1")
    build_data(model, 11, "string_1")
    build_data(model, 12, "string_1")
    build_data(model, nil, "string_1")
    build_data(model, nil, "string_1")
  end

  def build_data(model, foreign_key_value, string_value)
    data_values = model_unique_keys(model).each_with_object({}) do |key, obj|
      obj[key] = build_value(key, foreign_key_value, string_value)
    end
    model.create!(data_values)
  end

  def build_value(key, foreign_key_value, string_value)
    if key.to_s.ends_with?("id")
      foreign_key_value
    else
      string_value
    end
  end

  def analyze(model)
    original_values = {}
    duplicate_values = {}
    model.all.each do |record|
      index = record.attributes.symbolize_keys.slice(*model_unique_keys(model))
      if original_values[index]
        duplicate_values[index] << record.id
      else
        original_values[index] = record.id
        duplicate_values[index] ||= []
      end
    end

    return original_values, duplicate_values
  end

  def assert_before_migration_test_data(model, original_values, duplicate_values)
    expect(model.count).to eq(10)

    # Check there are 5 duplicates in the data
    expect(original_values.count).to eq(5)
    expect(duplicate_values.count).to eq(5)

    # Check that original values ids are the min or all duplicated ids
    original_values.each do |key, value|
      expect((duplicate_values[key] << value).min).to eq value
    end
  end

  def assert_after_migration_test_data(model, original_values, duplicate_values)
    expect(model.count).to eq(5)

    model.all.each do |record|
      expect(original_values[record.attributes.symbolize_keys.slice(*model_unique_keys(model))]).to eq record.id
    end
  end

  migration_context :up do
    it "manually checks we clean up duplicates in ContainerBuild build model" do
      model = CleanUpDuplicatesInContainersTables::ContainerBuild
      create_test_data(model)

      expect(model.pluck(*model_unique_keys(model))).to(
        match_array(
          [
            [10, "string_1"],
            [10, "string_1"],
            [10, "string_2"],
            [11, "string_1"],
            [11, "string_1"],
            [11, "string_1"],
            [11, "string_1"],
            [12, "string_1"],
            [nil, "string_1"],
            [nil, "string_1"]
          ]
        )
      )

      migrate

      expect(model.pluck(*model_unique_keys(model))).to(
        match_array(
          [
            [10, "string_1"],
            [10, "string_2"],
            [11, "string_1"],
            [12, "string_1"],
            [nil, "string_1"]
          ]
        )
      )
    end

    described_class::UNIQUE_INDEXES_FOR_MODELS.keys.each do |model|
      context "with model #{model}" do
        it "checks that the duplicate values are cleaned up" do
          create_test_data(model)

          original_values, duplicate_values = analyze(model)
          assert_before_migration_test_data(model, original_values, duplicate_values)
          migrate
          assert_after_migration_test_data(model, original_values, duplicate_values)
        end
      end
    end
  end
end

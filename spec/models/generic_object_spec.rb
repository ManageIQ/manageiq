describe GenericObject do
  let(:go_object_name) { "load_balancer_1" }
  let(:max_number)     { 100 }
  let(:server_name)    { "test_server" }
  let(:data_read)      { 345.67 }
  let(:s_time)         { Time.now.utc }

  let(:definition) do
    FactoryGirl.create(
      :generic_object_definition,
      :name       => "test_definition",
      :properties => {
        :attributes => {
          :max_number => "integer",
          :server     => "string",
          :flag       => "boolean",
          :data_read  => "float",
          :s_time     => "datetime"
        }
      }
    )
  end

  let(:go) do
    FactoryGirl.build(
      :generic_object,
      :generic_object_definition => definition,
      :name                      => go_object_name,
      :max_number                => max_number,
      :server                    => server_name,
      :flag                      => true,
      :data_read                 => data_read,
      :s_time                    => s_time
    )
  end

  it "should ensure presence of name" do
    o = GenericObject.new(:generic_object_definition => definition, :name => nil)
    expect(o).not_to be_valid
  end

  it "should ensure uniqueness of name" do
    GenericObject.new(:generic_object_definition => definition, :name => "MyGenericObject").save
    expect(GenericObject.new(:generic_object_definition => definition, :name => "MyGenericObject")).not_to be_valid
  end

  it "should require presence of GenericObjectDefinition" do
    expect { GenericObject.create!(:name => 'no_definition') }.to raise_error(ActiveRecord::RecordInvalid)
  end

  context "custom attributes" do
    it "can be accessed as an attribute" do
      go.save!
      expect(go.generic_object_definition).to eq(definition)
      expect(go.name).to                      eq(go_object_name)
      expect(go.max_number).to                eq(max_number)
      expect(go.server).to                    eq(server_name)
      expect(go.flag).to                      eq(true)
      expect(go.data_read).to                 eq(data_read)
      expect(go.s_time.to_i).to               be_same_time_as(s_time.to_i)
    end

    it "can be set as an attribute" do
      go.max_number = max_number + 100
      go.save!
      expect(go.reload.max_number).to eq(max_number + 100)
    end

    it "can't set undefined attributes" do
      expect { go.some_thing = 'not_defined' }.to raise_error(NoMethodError)
    end
  end

  context "#inspect" do
    it "AR attributes" do
      expect(go.inspect).to match(/generic_object_definition_id: #{definition.id}/)
      expect(go.inspect).to match(/name: "#{go_object_name}"/)
    end

    it "custom attributes" do
      go.save!
      expect(go.inspect).to match(/max_number: #{max_number}/)
      expect(go.inspect).to match(/server: "#{server_name}"/)
      expect(go.inspect).to match(/flag: true/)
      expect(go.inspect).to match(/s_time: "#{s_time.to_s(:db)}"/)
      expect(go.inspect).to match(/data_read: #{data_read}/)
    end
  end
end

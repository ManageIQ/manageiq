describe "MiqAeCollect" do
  before(:each) do
    MiqAeDatastore.reset
    @domain = "SPEC_DOMAIN"
    @user = FactoryGirl.create(:user_with_group)
    @model_data_dir = File.join(File.dirname(__FILE__), "data")
    EvmSpecHelper.import_yaml_model(File.join(@model_data_dir, "collect_data"), @domain)
  end

  after(:each) do
    MiqAeDatastore.reset
  end

  let(:months) { {"January" => 1, "October" => 10, "June" => 6, "July" => 7, "February" => 2, "May" => 5, "March" => 3, "December" => 12, "August" => 8, "September" => 9, "November" => 11, "April" => 4} }
  it "collects months" do
    ws = MiqAeEngine.instantiate("/TEST/COLLECT/INFO#get_months", @user)
    expect(ws).not_to be_nil

    # puts ws.to_xml
    months = ws.root("months")
    expect(months).not_to be_nil
    expect(months.class.to_s).to eq("Hash")
    expect(months.length).to eq(12)
    expect(months).to eq(months)
    expect(ws.root('sort')).to eq([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12])
    expect(ws.root('rsort')).to eq([12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1])
    expect(ws.root('count')).to eq(12)
    expect(ws.root('min')).to eq(1)
    expect(ws.root('max')).to eq(12)
    expect(ws.root('mean')).to eq(6.5)
  end

  let(:weekdays) { {"Wednesday" => 4, "Friday" => 6, "Saturday" => 7, "Tuesday" => 3, "Sunday" => 1, "Monday" => 2, "Thursday" => 5} }
  it "collects weekdays" do
    ws = MiqAeEngine.instantiate("/TEST/COLLECT/INFO#get_weekdays", @user)
    expect(ws).not_to be_nil
    # puts ws.to_xml
    weekdays = ws.root("weekdays")
    expect(weekdays).not_to be_nil
    expect(weekdays.class.to_s).to eq("Hash")
    expect(weekdays.length).to eq(7)
    expect(weekdays).to eq(weekdays)
    expect(ws.root('sum')).to eq(28)
  end

  it "collect on instance level overrides collect on class level" do
    c1 = MiqAeClass.find_by_namespace_and_name("#{@domain}/TEST", "COLLECT")
    i1 = c1.ae_instances.detect { |i| i.name == "INFO"   }
    f1 = c1.ae_fields.detect    { |f| f.name == "weekdays" }
    i1.set_field_collect(f1, "weekdays = [description]")

    ws = MiqAeEngine.instantiate("/TEST/COLLECT/INFO#get_weekdays", @user)
    expect(ws).not_to be_nil
    # puts ws.to_xml
    weekdays = ws.root("weekdays")
    expect(weekdays).not_to be_nil
    expect(weekdays.class.to_s).to eq("Array")
    expect(weekdays.length).to eq(7)
  end

  it "gets proper value base on environment" do
    ws = MiqAeEngine.instantiate("/TEST/COLLECT/INFO?environment=dev#get_random_number", @user)
    expect(ws).not_to be_nil
    expect(ws.root("number")).to eq(3)

    ws = MiqAeEngine.instantiate("/TEST/COLLECT/INFO?environment=test#get_random_number", @user)
    expect(ws).not_to be_nil
    expect(ws.root("number")).to eq(5)

    ws = MiqAeEngine.instantiate("/TEST/COLLECT/INFO?environment=foo#get_random_number", @user)
    expect(ws).not_to be_nil
    expect(ws.root("number")).to eq(1)
    ws = MiqAeEngine.instantiate("/TEST/COLLECT/INFO?environment=#get_random_number", @user)
    expect(ws).not_to be_nil
    expect(ws.root("number")).to eq(0)

    ws = MiqAeEngine.instantiate("/TEST/COLLECT/INFO#get_random_number", @user)
    expect(ws).not_to be_nil
    expect(ws.root("number")).to eq(0)
  end
end

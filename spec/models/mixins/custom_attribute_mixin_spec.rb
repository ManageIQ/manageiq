describe CustomAttributeMixin do
  let(:supported_factories) { [:vm_redhat, :host] }
  let(:test_class) do
    Class.new(ActiveRecord::Base) do
      def self.name; "TestClass"; end
      self.table_name = "vms"
      include CustomAttributeMixin
    end
  end

  it "defines #miq_custom_keys" do
    expect(test_class.new).to respond_to(:miq_custom_keys)
  end

  it "defines #miq_custom_get" do
    expect(test_class.new).to respond_to(:miq_custom_get)
  end

  it "defines #miq_custom_set" do
    expect(test_class.new).to respond_to(:miq_custom_set)
  end

  it "defines custom getter and setter methods" do
    t = test_class.new
    (1..9).each do |custom_id|
      custom_str = "custom_#{custom_id}"
      getter     = custom_str.to_sym
      setter     = "#{custom_str}=".to_sym

      expect(t).to respond_to(getter)
      expect(t).to respond_to(setter)
    end
  end

  it "#miq_custom_keys" do
    expect(test_class.new.miq_custom_keys).to eq([])
    supported_factories.each do |factory_name|
      object = FactoryGirl.create(factory_name)

      expect(object.miq_custom_keys).to eq([])

      key  = "foo"
      FactoryGirl.create(:miq_custom_attribute,
                         :resource_type => object.class.base_class.name,
                         :resource_id   => object.id,
                         :name          => key,
                         :value         => "bar")

      expect(object.reload.miq_custom_keys).to eq([key])

      key2 = "foobar"
      FactoryGirl.create(:miq_custom_attribute,
                         :resource_type => object.class.base_class.name,
                         :resource_id   => object.id,
                         :name          => key2,
                         :value         => "bar")
      expect(object.reload.miq_custom_keys).to match_array([key, key2])
    end
  end

  it "#miq_custom_set" do
    supported_factories.each do |factory_name|
      object = FactoryGirl.create(factory_name)

      key    = "foo"
      value  = "bar"
      source = 'EVM'

      expect(CustomAttribute.where(
        :resource_type => object.class.base_class.name,
        :resource_id   => object.id,
        :source        => source,
        :name          => key).first).to be_nil

      object.miq_custom_set(key, "")
      expect(CustomAttribute.where(
        :resource_type => object.class.base_class.name,
        :resource_id   => object.id,
        :source        => source,
        :name          => key).first).to be_nil

      object.miq_custom_set(key, value)
      expect(CustomAttribute.where(
        :resource_type => object.class.base_class.name,
        :resource_id   => object.id,
        :source        => source,
        :name          => key,
        :value         => value).first).not_to be_nil

      object.miq_custom_set(key, "")
      expect(CustomAttribute.where(
        :resource_type => object.class.base_class.name,
        :resource_id   => object.id,
        :source        => source,
        :name          => key).first).to be_nil
    end
  end

  it "#miq_custom_get" do
    supported_factories.each do |factory_name|
      object = FactoryGirl.create(factory_name)

      key   = "foo"
      value = "bar"

      expect(object.miq_custom_get(key)).to be_nil

      FactoryGirl.create(:miq_custom_attribute,
                         :resource_type => object.class.base_class.name,
                         :resource_id   => object.id,
                         :name          => key,
                         :value         => value)

      expect(object.reload.miq_custom_get(key)).to eq(value)
    end
  end
end

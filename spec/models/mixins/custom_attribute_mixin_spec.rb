describe CustomAttributeMixin do
  let(:supported_factories) { [:vm_redhat, :host] }
  let(:test_class) do
    Class.new(ActiveRecord::Base) do
      def self.name; "TestClass"; end
      self.table_name = "vms"
      include CustomAttributeMixin
    end
  end

  describe '#to_human' do
    let(:custom_attribute)                { 'virtual_custom_attribute_name' }
    let(:custom_attribute_with_section_1) { "virtual_custom_attribute_name#{described_class::SECTION_SEPARATOR}labels" }
    let(:custom_attribute_with_section_2) do
      "virtual_custom_attribute_name#{described_class::SECTION_SEPARATOR}docker_labels"
    end

    it 'returns human form of virtual custom attribute with sections' do
      expect(described_class.to_human(custom_attribute)).to eq('Custom Attribute: name')
    end

    it 'returns human form of virtual custom attribute' do
      expect(described_class.to_human(custom_attribute_with_section_1)).to eq('Labels: name')
    end

    it 'returns human form of virtual custom attribute' do
      expect(described_class.to_human(custom_attribute_with_section_2)).to eq('Docker Labels: name')
    end
  end

  describe '#custom_keys' do
    let!(:custom_attribute) { FactoryBot.create(:custom_attribute, :name => "attr_1", :value => 'value') }
    let!(:custom_attribute_with_section) do
      FactoryBot.create(:custom_attribute, :name => "attr_2", :value => 'value', :section => 'labels')
    end

    let!(:vm) do
      FactoryBot.create(:vm_redhat, :custom_attributes => [custom_attribute, custom_attribute_with_section])
    end

    it 'returns human form of virtual custom attribute with sections' do
      expect(vm.class.custom_keys).to match_array(["attr_1", "attr_2#{described_class::SECTION_SEPARATOR}labels"])
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
      object = FactoryBot.create(factory_name)

      expect(object.miq_custom_keys).to eq([])

      key  = "foo"
      FactoryBot.create(:miq_custom_attribute,
                         :resource_type => object.class.base_class.name,
                         :resource_id   => object.id,
                         :name          => key,
                         :value         => "bar")

      expect(object.reload.miq_custom_keys).to eq([key])

      key2 = "foobar"
      FactoryBot.create(:miq_custom_attribute,
                         :resource_type => object.class.base_class.name,
                         :resource_id   => object.id,
                         :name          => key2,
                         :value         => "bar")
      expect(object.reload.miq_custom_keys).to match_array([key, key2])
    end
  end

  it "#miq_custom_set" do
    supported_factories.each do |factory_name|
      object = FactoryBot.create(factory_name)

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
      object = FactoryBot.create(factory_name)

      key   = "foo"
      value = "bar"

      expect(object.miq_custom_get(key)).to be_nil

      FactoryBot.create(:miq_custom_attribute,
                         :resource_type => object.class.base_class.name,
                         :resource_id   => object.id,
                         :name          => key,
                         :value         => value)

      expect(object.reload.miq_custom_get(key)).to eq(value)
    end
  end
end

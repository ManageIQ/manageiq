RSpec.describe MiqAeMethod do
  let(:user) { FactoryBot.create(:user_with_group) }
  let(:sys_domain) { FactoryBot.create(:miq_ae_system_domain) }
  let(:domain) { FactoryBot.create(:miq_ae_domain) }
  let(:sub_domain) { FactoryBot.create(:miq_ae_namespace, :parent => domain) }

  let(:sys_class) { FactoryBot.create(:miq_ae_class, :namespace_id => sys_domain.id) }
  let(:reg_class) { FactoryBot.create(:miq_ae_class, :namespace_id => domain.id) }
  let(:sub_class) { FactoryBot.create(:miq_ae_class, :namespace_id => sub_domain.id) }

  describe "#editable" do
    it "should return editable as false if the parent namespace/class is not editable" do
      f1 = FactoryBot.create(:miq_ae_method,
                             :class_id => sys_class.id,
                             :name     => "foo_method")
      expect(f1.editable?(user)).to be_falsey
    end

    it "should return editable as true if the parent namespace/class is editable" do
      f1 = FactoryBot.create(:miq_ae_method,
                             :class_id => reg_class.id,
                             :name     => "foo_method")
      expect(f1.editable?(user)).to be_truthy
    end
  end

  describe ".lookup_by_class_id_and_name" do
    it "should lookup method" do
      f1 = FactoryBot.create(:miq_ae_method,
                             :class_id => sys_class.id,
                             :name     => "foo_method")
      expect(f1.editable?(user)).to be_falsey

      expect(MiqAeMethod.lookup_by_class_id_and_name(sys_class.id, "foo_method")).to eq(f1)
    end
  end

  it "doesn’t access database when unchanged model is saved" do
    f1 = FactoryBot.create(:miq_ae_method,
                           :class_id => reg_class.id,
                           :name     => "foo_method")
    expect { f1.valid? }.not_to make_database_queries
  end

  describe "#data_for_expression" do
    it "when the method has an embedded expression" do
      yaml_data = <<~YAML
        ---
        :db: OrchestrationTemplate
        :expression:
          and:
          - "=":
              field: OrchestrationTemplate-orderable
              value: 'true'
            :token: 1
          - INCLUDES:
              field: OrchestrationTemplate-type
              value: :user_input
            :token: 2
      YAML

      f1 = FactoryBot.create(:miq_ae_method,
                             :scope    => "instance",
                             :location => "expression",
                             :data     => yaml_data)

      expect(f1.data_for_expression).to eq YAML.load(yaml_data)
    end

    it "when the method is not an expression" do
      f1 = FactoryBot.create(:miq_ae_method,
                             :scope    => "instance",
                             :location => "inline")

      expect { f1.data_for_expression }.to raise_error(/is not an expression/)
    end
  end

  context "#copy" do
    let(:d1) { FactoryBot.create(:miq_ae_domain, :priority => 1) }
    let(:d2) { FactoryBot.create(:miq_ae_domain, :priority => 2) }
    let(:ns1) { FactoryBot.create(:miq_ae_namespace, :parent => d1) }
    let(:ns2) { FactoryBot.create(:miq_ae_namespace, :parent => d2) }
    let(:m1) { FactoryBot.create(:miq_ae_method, :class_id => cls1.id, :scope => "instance") }
    let(:m2) { FactoryBot.create(:miq_ae_method, :class_id => cls1.id, :scope => "instance") }
    let(:cls1) { FactoryBot.create(:miq_ae_class, :name => "cls1", :namespace_id => ns1.id) }

    it "copies instances under specified namespace" do
      options = {
        :domain             => d2.name,
        :namespace          => nil,
        :overwrite_location => false,
        :ids                => [m1.id, m2.id]
      }

      res = MiqAeMethod.copy(options)
      expect(res.count).to eq(2)
    end

    it "copy instances under same namespace raise error when class exists" do
      options = {
        :domain             => d1.name,
        :namespace          => ns1.fqname,
        :overwrite_location => false,
        :ids                => [m1.id, m2.id]
      }
      expect { MiqAeMethod.copy(options) }.to raise_error(RuntimeError)
    end

    it "replaces instances under same namespace when class exists" do
      options = {
        :domain             => d2.name,
        :namespace          => ns2.name,
        :overwrite_location => true,
        :ids                => [m1.id, m2.id]
      }

      res = MiqAeMethod.copy(options)
      expect(res.count).to eq(2)
    end
  end

  describe "#to_export_xml" do
    let(:miq_ae_method) do
      described_class.new(
        :class_id   => 321,
        :created_on => Time.now,
        :data       => "the data",
        :id         => 123,
        :inputs     => inputs,
        :updated_by => "me",
        :updated_on => Time.now
      )
    end

    let(:inputs) { [miq_ae_field] }
    let(:miq_ae_field) { MiqAeField.new }

    before do
      allow(miq_ae_field).to receive(:to_export_xml) do |options|
        options[:builder].inputs
      end
    end

    it "produces the expected xml" do
      expected_xml = <<~XML
        <MiqAeMethod name="" language="" scope="" location=""><![CDATA[the data]]><inputs/></MiqAeMethod>
      XML

      expect(miq_ae_method.to_export_xml).to eq(expected_xml.chomp)
    end
  end

  it "#domain" do
    m1 = FactoryBot.create(:miq_ae_method,
                           :class_id => sub_class.id,
                           :name     => "foo_method")
    expect(m1.domain).to eql(domain)
  end

  it "#to_export_yaml" do
    m1 = FactoryBot.create(:miq_ae_method,
                           :class_id => sub_class.id,
                           :name     => "foo_method")
    result = m1.to_export_yaml

    expect(result['name']).to eql('foo_method')
    expect(result['location']).to eql('inline')
    keys = result.keys
    expect(keys.exclude?('options')).to be_truthy
    expect(keys.exclude?('embedded_methods')).to be_truthy
  end
end

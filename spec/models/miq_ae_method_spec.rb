RSpec.describe MiqAeMethod do
  let(:user) { FactoryBot.create(:user_with_group) }
  it "should return editable as false if the parent namespace/class is not editable" do
    n1 = FactoryBot.create(:miq_ae_system_domain, :tenant => user.current_tenant)
    c1 = FactoryBot.create(:miq_ae_class, :namespace_id => n1.id, :name => "foo")
    f1 = FactoryBot.create(:miq_ae_method,
                            :class_id => c1.id,
                            :name     => "foo_method",
                            :scope    => "instance",
                            :language => "ruby",
                            :location => "inline")
    expect(f1.editable?(user)).to be_falsey
  end

  it "should return editable as true if the parent namespace/class is editable" do
    n1 = FactoryBot.create(:miq_ae_domain, :tenant => user.current_tenant)
    c1 = FactoryBot.create(:miq_ae_class, :namespace_id => n1.id, :name => "foo")
    f1 = FactoryBot.create(:miq_ae_method,
                            :class_id => c1.id,
                            :name     => "foo_method",
                            :scope    => "instance",
                            :language => "ruby",
                            :location => "inline")
    expect(f1.editable?(user)).to be_truthy
  end

  it "should lookup method" do
    n1 = FactoryBot.create(:miq_ae_system_domain, :tenant => user.current_tenant)
    c1 = FactoryBot.create(:miq_ae_class, :namespace_id => n1.id, :name => "foo")
    f1 = FactoryBot.create(:miq_ae_method,
                           :class_id => c1.id,
                           :name     => "foo_method",
                           :scope    => "instance",
                           :language => "ruby",
                           :location => "inline")
    expect(f1.editable?(user)).to be_falsey

    expect(MiqAeMethod.lookup_by_class_id_and_name(c1.id, "foo_method")).to eq(f1)
  end

  it "doesn’t access database when unchanged model is saved" do
    n1 = FactoryBot.create(:miq_ae_system_domain, :tenant => user.current_tenant)
    c1 = FactoryBot.create(:miq_ae_class, :namespace_id => n1.id, :name => "foo")
    f1 = FactoryBot.create(:miq_ae_method,
                           :class_id => c1.id,
                           :name     => "foo_method",
                           :scope    => "instance",
                           :language => "ruby",
                           :location => "inline")
    expect { f1.valid? }.not_to make_database_queries
  end

  context "#copy" do
    let(:d2) { FactoryBot.create(:miq_ae_domain, :name => "domain2", :priority => 2) }
    let(:ns1) { FactoryBot.create(:miq_ae_namespace, :name => "ns1", :parent => @d1) }
    let(:m1) { FactoryBot.create(:miq_ae_method, :class_id => @cls1.id, :name => "foo_method1", :scope => "instance", :language => "ruby", :location => "inline") }
    let(:m2) { FactoryBot.create(:miq_ae_method, :class_id => @cls1.id, :name => "foo_method2", :scope => "instance", :language => "ruby", :location => "inline") }
    before do
      @d1 = FactoryBot.create(:miq_ae_domain, :name => "domain1", :parent => nil, :priority => 1)
      @cls1 = FactoryBot.create(:miq_ae_class, :name => "cls1", :namespace_id => ns1.id)
      @ns2 = FactoryBot.create(:miq_ae_namespace, :name => "ns2", :parent => d2)
    end

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
        :domain             => @d1.name,
        :namespace          => ns1.fqname,
        :overwrite_location => false,
        :ids                => [m1.id, m2.id]
      }
      expect { MiqAeMethod.copy(options) }.to raise_error(RuntimeError)
    end

    it "replaces instances under same namespace when class exists" do
      options = {
        :domain             => d2.name,
        :namespace          => @ns2.name,
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
      expected_xml = <<-XML
<MiqAeMethod name="" language="" scope="" location=""><![CDATA[the data]]><inputs/></MiqAeMethod>
      XML

      expect(miq_ae_method.to_export_xml).to eq(expected_xml.chomp)
    end
  end

  it "#domain" do
    d1 = FactoryBot.create(:miq_ae_system_domain, :name => 'dom1', :priority => 10)
    n1 = FactoryBot.create(:miq_ae_namespace, :name => 'ns1', :parent => d1)
    c1 = FactoryBot.create(:miq_ae_class, :namespace_id => n1.id, :name => "foo")
    m1 = FactoryBot.create(:miq_ae_method,
                            :class_id => c1.id,
                            :name     => "foo_method",
                            :scope    => "instance",
                            :language => "ruby",
                            :location => "inline")
    expect(m1.domain.name).to eql('dom1')
  end

  it "#to_export_yaml" do
    d1 = FactoryBot.create(:miq_ae_system_domain, :name => 'dom1', :priority => 10)
    n1 = FactoryBot.create(:miq_ae_namespace, :name => 'ns1', :parent => d1)
    c1 = FactoryBot.create(:miq_ae_class, :namespace_id => n1.id, :name => "foo")
    m1 = FactoryBot.create(:miq_ae_method,
                            :class_id => c1.id,
                            :name     => "foo_method",
                            :scope    => "instance",
                            :language => "ruby",
                            :location => "inline")
    result = m1.to_export_yaml

    expect(result['name']).to eql('foo_method')
    expect(result['location']).to eql('inline')
    keys = result.keys
    expect(keys.exclude?('options')).to be_truthy
    expect(keys.exclude?('embedded_methods')).to be_truthy
  end
end

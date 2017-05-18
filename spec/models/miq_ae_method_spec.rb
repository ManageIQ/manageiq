describe MiqAeMethod do
  before do
    @user = FactoryGirl.create(:user_with_group)
  end

  it "should return editable as false if the parent namespace/class is not editable" do
    n1 = FactoryGirl.create(:miq_ae_system_domain, :tenant => @user.current_tenant)
    c1 = FactoryGirl.create(:miq_ae_class, :namespace_id => n1.id, :name => "foo")
    f1 = FactoryGirl.create(:miq_ae_method,
                            :class_id => c1.id,
                            :name     => "foo_method",
                            :scope    => "instance",
                            :language => "ruby",
                            :location => "inline")
    expect(f1.editable?(@user)).to be_falsey
  end

  it "should return editable as true if the parent namespace/class is editable" do
    n1 = FactoryGirl.create(:miq_ae_domain, :tenant => @user.current_tenant)
    c1 = FactoryGirl.create(:miq_ae_class, :namespace_id => n1.id, :name => "foo")
    f1 = FactoryGirl.create(:miq_ae_method,
                            :class_id => c1.id,
                            :name     => "foo_method",
                            :scope    => "instance",
                            :language => "ruby",
                            :location => "inline")
    expect(f1.editable?(@user)).to be_truthy
  end

  context "#copy" do
    before do
      @d1 = FactoryGirl.create(:miq_ae_namespace, :name => "domain1", :parent_id => nil, :priority => 1)
      @ns1 = FactoryGirl.create(:miq_ae_namespace, :name => "ns1", :parent_id => @d1.id)
      @cls1 = FactoryGirl.create(:miq_ae_class, :name => "cls1", :namespace_id => @ns1.id)
      @m1 = FactoryGirl.create(:miq_ae_method,
                               :class_id => @cls1.id,
                               :name     => "foo_method1",
                               :scope    => "instance",
                               :language => "ruby",
                               :location => "inline")
      @m2 = FactoryGirl.create(:miq_ae_method,
                               :class_id => @cls1.id,
                               :name     => "foo_method2",
                               :scope    => "instance",
                               :language => "ruby",
                               :location => "inline")

      @d2 = FactoryGirl.create(:miq_ae_domain, :name => "domain2", :priority => 2)
      @ns2 = FactoryGirl.create(:miq_ae_namespace, :name => "ns2", :parent_id => @d2.id)
    end

    it "copies instances under specified namespace" do
      options = {
        :domain             => @d2.name,
        :namespace          => nil,
        :overwrite_location => false,
        :ids                => [@m1.id, @m2.id]
      }

      res = MiqAeMethod.copy(options)
      expect(res.count).to eq(2)
    end

    it "copy instances under same namespace raise error when class exists" do
      options = {
        :domain             => @d1.name,
        :namespace          => @ns1.fqname,
        :overwrite_location => false,
        :ids                => [@m1.id, @m2.id]
      }
      expect { MiqAeMethod.copy(options) }.to raise_error(RuntimeError)
    end

    it "replaces instances under same namespace when class exists" do
      options = {
        :domain             => @d2.name,
        :namespace          => @ns2.name,
        :overwrite_location => true,
        :ids                => [@m1.id, @m2.id]
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
    d1 = FactoryGirl.create(:miq_ae_system_domain, :name => 'dom1', :priority => 10)
    n1 = FactoryGirl.create(:miq_ae_namespace, :name => 'ns1', :parent_id => d1.id)
    c1 = FactoryGirl.create(:miq_ae_class, :namespace_id => n1.id, :name => "foo")
    m1 = FactoryGirl.create(:miq_ae_method,
                            :class_id => c1.id,
                            :name     => "foo_method",
                            :scope    => "instance",
                            :language => "ruby",
                            :location => "inline")
    expect(m1.domain.name).to eql('dom1')
  end
end

require "spec_helper"

describe MiqAeMethod do
  it "should return editable as false if the parent namespace/class is not editable" do
    n1 = FactoryGirl.create(:miq_ae_namespace, :name => 'ns1', :priority => 10, :system => true)
    c1 = FactoryGirl.create(:miq_ae_class, :namespace_id => n1.id, :name => "foo")
    f1 = FactoryGirl.create(:miq_ae_method,
                            :class_id => c1.id,
                            :name     => "foo_method",
                            :scope    => "instance",
                            :language => "ruby",
                            :location => "inline")
    f1.should_not be_editable
  end

  it "should return editable as true if the parent namespace/class is editable" do
    n1 = FactoryGirl.create(:miq_ae_namespace, :name => 'ns1')
    c1 = FactoryGirl.create(:miq_ae_class, :namespace_id => n1.id, :name => "foo")
    f1 = FactoryGirl.create(:miq_ae_method,
                            :class_id => c1.id,
                            :name     => "foo_method",
                            :scope    => "instance",
                            :language => "ruby",
                            :location => "inline")
    f1.should be_editable
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

      @d2 = FactoryGirl.create(:miq_ae_namespace,
                               :name => "domain2", :parent_id => nil, :priority => 2, :system => false)
      @ns2 = FactoryGirl.create(:miq_ae_namespace, :name => "ns2", :parent_id => @d2.id)
    end

    it "copies instances under specified namespace" do
      domain             = @d2.name
      namespace          = nil
      overwrite_location = false
      selected_items     = [@m1.id, @m2.id]

      res = MiqAeMethod.copy(selected_items, domain, namespace, overwrite_location)
      res.count.should eq(2)
    end

    it "copy instances under same namespace raise error when class exists" do
      domain             = @d1.name
      namespace          = @ns1.fqname
      overwrite_location = false
      selected_items     = [@m1.id, @m2.id]
      expect { MiqAeMethod.copy(selected_items, domain, namespace, overwrite_location) }.to raise_error(RuntimeError)
    end

    it "replaces instances under same namespace when class exists" do
      domain             = @d2.name
      namespace          = @ns2.name
      overwrite_location = true
      selected_items     = [@m1.id, @m2.id]

      res = MiqAeMethod.copy(selected_items, domain, namespace, overwrite_location)
      res.count.should eq(2)
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
      miq_ae_field.stub(:to_export_xml) do |options|
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
end

require "spec_helper"

describe MiqAeClassCopy do

  before do
    @src_domain  = 'SPEC_DOMAIN'
    @dest_domain = 'FRED'
    @src_ns      = 'NS1'
    @dest_ns     = 'NS1'
    @src_class   = 'CLASS1'
    @dest_class  = 'CLASS1'
    @src_fqname  = "#{@src_domain}/#{@src_ns}/#{@src_class}"
    @yaml_file   = File.join(File.dirname(__FILE__), 'miq_ae_copy_data', 'class_copy1.yaml')
    MiqAeDatastore.reset
    EvmSpecHelper.import_yaml_model_from_file(@yaml_file, @src_domain)
  end

  context "clone the class to a new domain" do
    before do
      @ns1 = MiqAeNamespace.find_by_fqname("#{@src_domain}/#{@src_ns}", false)
    end

    it "after copy both classes in DB should be congruent" do
      class1 = MiqAeClass.find_by_namespace_id_and_name(@ns1.id, @src_class)
      class2 = MiqAeClassCopy.new(@src_fqname).to_domain(@dest_domain)
      class_check_status(class1, class2, MiqAeClassCompareFields::CONGRUENT_SCHEMA)
      @ns2 = MiqAeNamespace.find_by_fqname("#{@dest_domain}/#{@src_ns}", false)
      class2 = MiqAeClass.find_by_namespace_id_and_name(@ns2.id, @src_class)
      class2.should_not be_nil
    end
  end

  context "clone the class to a new domain with a different namespace" do
    before do
      @ns1 = MiqAeNamespace.find_by_fqname("#{@src_domain}/#{@src_ns}", false)
    end

    it "after copy both classes in DB should be congruent" do
      class1 = MiqAeClass.find_by_namespace_id_and_name(@ns1.id, @src_class)
      new_ns   = "NS3/NS4"
      class2 = MiqAeClassCopy.new(@src_fqname).to_domain(@dest_domain, new_ns)
      class_check_status(class1, class2, MiqAeClassCompareFields::CONGRUENT_SCHEMA)
      @ns2 = MiqAeNamespace.find_by_fqname("#{@dest_domain}/#{new_ns}", false)
      class2 = MiqAeClass.find_by_namespace_id_and_name(@ns2.id, @src_class)
      class2.should_not be_nil
    end
  end

  context "copy to a new classname in the same domain" do
    before do
      @ns1 = MiqAeNamespace.find_by_fqname("#{@src_domain}/#{@src_ns}", false)
    end

    it "after copy both classes in DB should be congruent" do
      new_name = "SAME_AS_#{@src_class}"
      class1 = MiqAeClass.find_by_namespace_id_and_name(@ns1.id, @src_class)
      class2 = MiqAeClassCopy.new(@src_fqname).as(new_name)
      class_check_status(class1, class2, MiqAeClassCompareFields::CONGRUENT_SCHEMA)
      class2 = MiqAeClass.find_by_namespace_id_and_name(@ns1.id, new_name)
      class2.should_not be_nil
    end
  end

  context "copy to a existing class in the same domain" do
    before do
      @ns1 = MiqAeNamespace.find_by_fqname("#{@src_domain}/#{@src_ns}", false)
    end

    it "copy should fail with error" do
      expect { MiqAeClassCopy.new(@src_fqname).as(@src_class) }.to raise_error(RuntimeError)
    end
  end

  context "copy to a new class name in the same domain but different namespace" do
    before do
      @ns1 = MiqAeNamespace.find_by_fqname("#{@src_domain}/#{@src_ns}", false)
    end

    it "after copy both classes in DB should be congruent" do
      new_name = "SAME_AS_#{@src_class}"
      new_ns   = "NS3/NS4"
      class1 = MiqAeClass.find_by_namespace_id_and_name(@ns1.id, @src_class)
      class2 = MiqAeClassCopy.new(@src_fqname).as(new_name, new_ns)
      class_check_status(class1, class2, MiqAeClassCompareFields::CONGRUENT_SCHEMA)
      @ns2 = MiqAeNamespace.find_by_fqname("#{@src_domain}/#{new_ns}", false)
      class2 = MiqAeClass.find_by_namespace_id_and_name(@ns2.id, new_name)
      class2.should_not be_nil
    end
  end

  context "copy class onto itself" do
    it "pass in same domain" do
      expect { MiqAeClassCopy.new(@src_fqname).to_domain(@src_domain, nil, true) }.to raise_error(RuntimeError)
    end

    it "pass in same classname" do
      expect { MiqAeClassCopy.new(@src_fqname).as(@src_class, nil, true) }.to raise_error(RuntimeError)
    end
  end

  def class_check_status(class1, class2, status)
    diff_obj = MiqAeClassCompareFields.new(class1, class2)
    diff_obj.compare
    diff_obj.status.should equal(status)
  end

end

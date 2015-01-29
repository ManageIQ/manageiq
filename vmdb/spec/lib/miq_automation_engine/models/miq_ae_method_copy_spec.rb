require "spec_helper"

describe MiqAeMethodCopy do

  before do
    @src_domain     = 'SPEC_DOMAIN'
    @dest_domain    = 'FRED'
    @src_ns         = 'NS1'
    @dest_ns        = 'NS1'
    @src_class      = 'CLASS1'
    @dest_class     = 'CLASS1'
    @src_method     = 'test_method'
    @dest_method    = 'test_method_diff_script'
    @builtin_method = 'send_email'
    @dest_ns        = 'NSX/NSY'
    @src_fqname     = "#{@src_domain}/#{@src_ns}/#{@src_class}/#{@src_method}"
    @yaml_file      = File.join(File.dirname(__FILE__), 'miq_ae_copy_data', 'miq_ae_method_copy.yaml')
    MiqAeDatastore.reset
    EvmSpecHelper.import_yaml_model_from_file(@yaml_file, @src_domain)
  end

  context 'clone method' do
    before do
      @ns1 = MiqAeNamespace.find_by_fqname("#{@src_domain}/#{@src_ns}", false)
      @class1 = MiqAeClass.find_by_namespace_id_and_name(@ns1.id, @src_class)
      @meth1  = MiqAeMethod.find_by_class_id_and_name(@class1.id, @src_method)
    end

    it 'after copy both inline methods in DB should be congruent' do
      MiqAeMethodCopy.new(@src_fqname).to_domain(@dest_domain)
      ns2 = MiqAeNamespace.find_by_fqname("#{@dest_domain}/#{@src_ns}", false)
      class2 = MiqAeClass.find_by_namespace_id_and_name(ns2.id, @src_class)
      meth2  = MiqAeMethod.find_by_class_id_and_name(class2.id, @src_method)
      validate_method(@meth1, meth2, MiqAeMethodCompare::CONGRUENT_METHOD)
    end

    it 'after copy both builtin methods in DB should be congruent' do
      builtin_fqname = "#{@src_domain}/#{@src_ns}/#{@src_class}/#{@builtin_method}"
      meth1  = MiqAeMethod.find_by_class_id_and_name(@class1.id, @builtin_method)
      MiqAeMethodCopy.new(builtin_fqname).to_domain(@dest_domain)
      ns2 = MiqAeNamespace.find_by_fqname("#{@dest_domain}/#{@src_ns}", false)
      class2 = MiqAeClass.find_by_namespace_id_and_name(ns2.id, @src_class)
      meth2  = MiqAeMethod.find_by_class_id_and_name(class2.id, @builtin_method)
      validate_method(meth1, meth2, MiqAeMethodCompare::CONGRUENT_METHOD)
    end

    it 'overwrite an existing method' do
      meth2  = MiqAeMethod.find_by_class_id_and_name(@class1.id, @dest_method)
      validate_method(@meth1, meth2, MiqAeMethodCompare::INCOMPATIBLE_METHOD)
      MiqAeMethodCopy.new(@src_fqname).as(@dest_method, nil, true)
      meth2  = MiqAeMethod.find_by_class_id_and_name(@class1.id, @dest_method)
      validate_method(@meth1, meth2, MiqAeMethodCompare::CONGRUENT_METHOD)
    end

    it 'overwrite an existing method should raise error' do
      meth2  = MiqAeMethod.find_by_class_id_and_name(@class1.id, @dest_method)
      validate_method(@meth1, meth2, MiqAeMethodCompare::INCOMPATIBLE_METHOD)
      expect { MiqAeMethodCopy.new(@src_fqname).as(@dest_method) }.to raise_error(RuntimeError)
    end

    it 'copy method to a different namespace in the same domain' do
      MiqAeMethodCopy.new(@src_fqname).as(@src_method, @dest_ns, true)
      ns2 = MiqAeNamespace.find_by_fqname("#{@src_domain}/#{@dest_ns}", false)
      class2 = MiqAeClass.find_by_namespace_id_and_name(ns2.id, @src_class)
      meth2  = MiqAeMethod.find_by_class_id_and_name(class2.id, @src_method)
      validate_method(@meth1, meth2, MiqAeMethodCompare::CONGRUENT_METHOD)
    end

    it 'copy method to a different namespace in a different domain' do
      MiqAeMethodCopy.new(@src_fqname).to_domain(@dest_domain, @dest_ns, true)
      ns2 = MiqAeNamespace.find_by_fqname("#{@dest_domain}/#{@dest_ns}", false)
      class2 = MiqAeClass.find_by_namespace_id_and_name(ns2.id, @src_class)
      meth2  = MiqAeMethod.find_by_class_id_and_name(class2.id, @src_method)
      validate_method(@meth1, meth2, MiqAeMethodCompare::CONGRUENT_METHOD)
    end

  end

  context 'copy onto itself' do
    it 'copy into the same domain' do
      expect { MiqAeMethodCopy.new(@src_fqname).to_domain(@src_domain, nil, true) }.to raise_error(RuntimeError)
    end

    it 'copy with the same name' do
      expect { MiqAeMethodCopy.new(@src_fqname).as(@src_method, nil, true) }.to raise_error(RuntimeError)
    end

  end

  context 'copy multiple' do
    it 'methods' do
      domain = 'Fred'
      fqname = 'test1'
      ids    = [1, 2, 3]
      miq_ae_method_copy = double(MiqAeMethodCopy)
      miq_ae_method = mock_model(MiqAeMethod)
      miq_ae_method_copy.should_receive(:to_domain).with(domain, nil, false).exactly(ids.length).times { miq_ae_method }
      new_ids = [miq_ae_method.id] * ids.length
      miq_ae_method.should_receive(:fqname_from_objects).with(no_args).exactly(ids.length).times { fqname }
      MiqAeMethod.should_receive(:find).with(an_instance_of(Fixnum)).exactly(ids.length).times { miq_ae_method }
      MiqAeMethodCopy.should_receive(:new).with(fqname).exactly(ids.length).times { miq_ae_method_copy }
      MiqAeMethodCopy.copy_multiple(ids, domain).should match_array(new_ids)
    end
  end

  def validate_method(meth1, meth2, status)
    obj = MiqAeMethodCompare.new(meth1, meth2)
    obj.compare
    obj.status.should eq(status)
  end

end

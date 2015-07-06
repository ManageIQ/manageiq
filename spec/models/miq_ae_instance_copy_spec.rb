require "spec_helper"

describe MiqAeInstanceCopy do

  before do
    @src_domain    = 'SPEC_DOMAIN'
    @dest_domain   = 'FRED'
    @src_ns        = 'NS1'
    @dest_ns       = 'NS1'
    @src_class     = 'CLASS1'
    @dest_class    = 'CLASS1'
    @src_instance  = 'default'
    @dest_instance = 'default2'
    @dest_ns       = 'NSX/NSY'
    @src_fqname    = "#{@src_domain}/#{@src_ns}/#{@src_class}/#{@src_instance}"
    @yaml_file   = File.join(File.dirname(__FILE__), 'miq_ae_copy_data', 'miq_ae_instance_copy.yaml')
    MiqAeDatastore.reset
    EvmSpecHelper.import_yaml_model_from_file(@yaml_file, @src_domain)
  end

  context 'clone instance' do
    before do
      @ns1 = MiqAeNamespace.find_by_fqname("#{@src_domain}/#{@src_ns}", false)
      @class1 = MiqAeClass.find_by_namespace_id_and_name(@ns1.id, @src_class)
      @inst1  = MiqAeInstance.find_by_class_id_and_name(@class1.id, @src_instance)
    end

    it 'after copy both instances in DB should be congruent' do
      MiqAeInstanceCopy.new(@src_fqname).to_domain(@dest_domain)
      ns2 = MiqAeNamespace.find_by_fqname("#{@dest_domain}/#{@src_ns}", false)
      class2 = MiqAeClass.find_by_namespace_id_and_name(ns2.id, @src_class)
      inst2  = MiqAeInstance.find_by_class_id_and_name(class2.id, @src_instance)
      validate_instance(@inst1, inst2, MiqAeInstanceCompareValues::CONGRUENT_INSTANCE)
    end

    it 'with overwrite an existing instance should get updated' do
      inst2  = MiqAeInstance.find_by_class_id_and_name(@class1.id, @dest_instance)
      validate_instance(@inst1, inst2, MiqAeInstanceCompareValues::COMPATIBLE_INSTANCE)
      MiqAeInstanceCopy.new(@src_fqname).as(@dest_instance, nil, true)
      inst2  = MiqAeInstance.find_by_class_id_and_name(@class1.id, @dest_instance)
      validate_instance(@inst1, inst2, MiqAeInstanceCompareValues::CONGRUENT_INSTANCE)
    end

    it 'without overwrite an existing instance should raise error' do
      inst2  = MiqAeInstance.find_by_class_id_and_name(@class1.id, @dest_instance)
      validate_instance(@inst1, inst2, MiqAeInstanceCompareValues::COMPATIBLE_INSTANCE)
      expect { MiqAeInstanceCopy.new(@src_fqname).as(@dest_instance) }.to raise_error(RuntimeError)
    end

    it 'copy instance to a different namespace in the same domain' do
      MiqAeInstanceCopy.new(@src_fqname).as(@src_instance, @dest_ns, true)
      ns2 = MiqAeNamespace.find_by_fqname("#{@src_domain}/#{@dest_ns}", false)
      class2 = MiqAeClass.find_by_namespace_id_and_name(ns2.id, @src_class)
      inst2  = MiqAeInstance.find_by_class_id_and_name(class2.id, @src_instance)
      validate_instance(@inst1, inst2, MiqAeInstanceCompareValues::CONGRUENT_INSTANCE)
    end

    it 'copy instance to a different namespace in a different domain' do
      MiqAeInstanceCopy.new(@src_fqname).to_domain(@dest_domain, @dest_ns, true)
      ns2 = MiqAeNamespace.find_by_fqname("#{@dest_domain}/#{@dest_ns}", false)
      class2 = MiqAeClass.find_by_namespace_id_and_name(ns2.id, @src_class)
      inst2  = MiqAeInstance.find_by_class_id_and_name(class2.id, @src_instance)
      validate_instance(@inst1, inst2, MiqAeInstanceCompareValues::CONGRUENT_INSTANCE)
    end

  end

  context 'incompatible schema' do
    before do
      @ns1 = MiqAeNamespace.find_by_fqname("#{@src_domain}/#{@src_ns}", false)
      @class1 = MiqAeClass.find_by_namespace_id_and_name(@ns1.id, @src_class)
      @inst1  = MiqAeInstance.find_by_class_id_and_name(@class1.id, @src_instance)
    end

    it 'by default copy should fail' do
      expect { MiqAeInstanceCopy.new(@src_fqname).as('incompatible_one', 'NS2', true) }.to raise_error(RuntimeError)
    end

    it 'allow if the incompatible flag is set' do
      cp = MiqAeInstanceCopy.new(@src_fqname)
      cp.flags = MiqAeClassCompareFields::INCOMPATIBLE_SCHEMA
      cp.as('incompatible_one', 'NS2', true)
      ns2 = MiqAeNamespace.find_by_fqname("#{@src_domain}/ns2", false)
      ic_class = MiqAeClass.find_by_namespace_id_and_name(ns2.id, @src_class)
      MiqAeInstance.find_by_class_id_and_name(ic_class.id, 'incompatible_one').should_not be_nil
    end
  end

  context 'copy onto itself' do
    it 'copy into the same domain' do
      expect { MiqAeInstanceCopy.new(@src_fqname).to_domain(@src_domain, nil, true) }.to raise_error(RuntimeError)
    end

    it 'copy with the same name' do
      expect { MiqAeInstanceCopy.new(@src_fqname).as(@src_instance, nil, true) }.to raise_error(RuntimeError)
    end
  end

  context 'copy multiple' do
    it 'instances' do
      domain = 'Fred'
      fqname = 'test1'
      ids    = [1, 2, 3]
      ins_copy = double(MiqAeInstanceCopy)
      ins = mock_model(MiqAeInstance)
      ins_copy.should_receive(:to_domain).with(domain, nil, false).exactly(ids.length).times { ins }
      new_ids = [ins.id] * ids.length
      ins.should_receive(:fqname).with(no_args).exactly(ids.length).times { fqname }
      MiqAeInstance.should_receive(:find).with(an_instance_of(Fixnum)).exactly(ids.length).times { ins }
      MiqAeInstanceCopy.should_receive(:new).with(fqname, true).exactly(1).times { ins_copy }
      MiqAeInstanceCopy.should_receive(:new).with(fqname, false).exactly(ids.length - 1).times { ins_copy }
      MiqAeInstanceCopy.copy_multiple(ids, domain).should match_array(new_ids)
    end
  end

  def validate_instance(instance1, instance2, status)
    obj = MiqAeInstanceCompareValues.new(instance1, instance2)
    obj.compare
    obj.status.should eq(status)
  end

end

require "spec_helper"
require "miq-xml"

describe MiqAeDatastore do
  before(:each) do
    @ver_fname = File.expand_path(File.join(File.dirname(__FILE__), "version.xml"))

    @export_xml = <<-XML
      <MiqAeDatastore version="1.0">
        <MiqAeClass name="VM" namespace="Factory" display_name="Virtual Machine">
          <MiqAeMethod name="CustomizeRequest" language="ruby" scope="instance" location="inline"><![CDATA[# end]]>    </MiqAeMethod>
          <MiqAeSchema>
            <MiqAeField name="execute" substitute="true" aetype="method" datatype="string" priority="1" message="create">
            </MiqAeField>
          </MiqAeSchema>
        </MiqAeClass>
        <MiqAeClass name="test_class" namespace="Factory/test" display_name="test namespace">
          <MiqAeMethod name="test_method" language="ruby" scope="instance" location="inline"><![CDATA[# end]]>    </MiqAeMethod>
          <MiqAeSchema>
            <MiqAeField name="execute" substitute="true" aetype="method" datatype="string" priority="1" message="create">
            </MiqAeField>
          </MiqAeSchema>
        </MiqAeClass>
        <MiqAeClass name="DHCP_Server" namespace="EVMApplications/Provisioning" display_name="DHCP Server">
          <MiqAeSchema>
            <MiqAeField name="name" substitute="true" aetype="attribute" datatype="string" priority="1" message="create">
            </MiqAeField>
          </MiqAeSchema>
        </MiqAeClass>
      </MiqAeDatastore>
    XML

    @defaults_miq_ae_field = {}
    @defaults_miq_ae_field[:message]    = MiqAeField.default(:message)
    @defaults_miq_ae_field[:substitute] = MiqAeField.default(:substitute).to_s
  end

  after(:each) do
    File.delete(@ver_fname) if File.exist?(@ver_fname)
  end

  def set_version_xml(v)
    v = v.nil? ? "" : "version='#{v}'"
    xml = <<-XML
    <MiqAeDatastore #{v}>
      <MiqAeClass name="AUTOMATE" namespace="EVM">
        <MiqAeSchema>
          <MiqAeField name="attr1" aetype="attribute" />
        </MiqAeSchema>
        <MiqAeInstance name="test1"/>
      </MiqAeClass>
    </MiqAeDatastore>
    XML
    File.open(@ver_fname, "w") { |f| f.write(xml) }
  end

  it "should test version" do
    MiqAeDatastore.reset
    set_version_xml(MiqAeDatastore::XML_VERSION_MIN_SUPPORTED)
    lambda { MiqAeDatastore.import(@ver_fname) }.should_not raise_error

    MiqAeDatastore.reset
    set_version_xml(MiqAeDatastore::XML_VERSION_MIN_SUPPORTED.to_f + 0.1)
    lambda { MiqAeDatastore.import(@ver_fname) }.should_not raise_error

    MiqAeDatastore.reset
    set_version_xml(MiqAeDatastore::XML_VERSION_MIN_SUPPORTED.to_f - 0.1)
    lambda { MiqAeDatastore.import(@ver_fname) }.should raise_error(RuntimeError)

    MiqAeDatastore.reset
    set_version_xml(nil)
    lambda { MiqAeDatastore.import(@ver_fname) }.should raise_error(RuntimeError)
  end

  it ".backup" do
    MiqAeYamlExportZipfs.any_instance.should_receive(:export).once
    MiqAeDatastore.backup('zip_file'  => 'dummy', 'overwrite' => true)
  end

  it ".restore" do
    MiqAeYamlImport.any_instance.should_receive(:import).once
    MiqAeDatastore.restore(nil)
  end

  it ".upload" do
    fd = double(:original_filename => "dummy.zip", :read => "junk", :eof => true, :close => true)
    import_file = File.expand_path(File.join(Rails.root, "tmp/miq_automate_engine", "dummy.zip"))
    MiqAeDatastore.should_receive(:import_yaml_zip).with(import_file, "*").once
    MiqAeDatastore.upload(fd, "dummy.zip")
  end

  it "should test export" do
    pending("XML Export has been deprecated in favor of YAML export")
    base_hash = XmlHash.load(@export_xml)

    MiqAeDatastore.reset
    [MiqAeClass, MiqAeField, MiqAeInstance, MiqAeNamespace, MiqAeMethod, MiqAeValue].each { |k| k.count.should == 0 }

    MiqAeDatastore::Import.load_xml(@export_xml)

    export1 = MiqAeDatastore.export
    export1_name = File.join(File.dirname(__FILE__), "test_export1.xml")
    File.open(export1_name, "w") { |f| f.write(export1) }
    export1_hash = XmlHash.loadFile(export1_name)

    MiqAeDatastore.reset
    [MiqAeClass, MiqAeField, MiqAeInstance, MiqAeNamespace, MiqAeMethod, MiqAeValue].each { |k|  k.count.should == 0 }

    MiqAeDatastore.import(export1_name)
    File.delete(export1_name)
    export2 = MiqAeDatastore.export
    export2_name = File.join(File.dirname(__FILE__), "test_export2.xml")
    File.open(export2_name, "w") { |f| f.write(export2) }
    export2_hash = XmlHash.loadFile(export2_name)
    File.delete(export2_name)

    compare_models_with_base_extended(export1_hash, export2_hash, base_hash)

  end


  it "should test class export" do
    pending("XML Export has been deprecated in favor of YAML export")
    base_hash = XmlHash.load(@export_xml)

    MiqAeDatastore.reset
    [MiqAeClass, MiqAeField, MiqAeInstance, MiqAeNamespace, MiqAeMethod, MiqAeValue].each { |k| k.count.should == 0 }

    MiqAeDatastore::Import.load_xml(@export_xml)

    export1 = MiqAeDatastore.export_class("Factory", "vm")
    export1_name = File.join(File.dirname(__FILE__), "test_class_export1.xml")
    File.open(export1_name, "w") { |f| f.write(export1) }
    export1_hash = XmlHash.loadFile(export1_name)

    MiqAeDatastore.reset
    [MiqAeClass, MiqAeField, MiqAeInstance, MiqAeNamespace, MiqAeMethod, MiqAeValue].each { |k|  k.count.should == 0 }

    MiqAeDatastore.import(export1_name)
    File.delete(export1_name)
    export2 = MiqAeDatastore.export_class("Factory", "vm")
    export2_name = File.join(File.dirname(__FILE__), "test_class_export2.xml")
    File.open(export2_name, "w") { |f| f.write(export2) }
    export2_hash = XmlHash.loadFile(export2_name)
    File.delete(export2_name)

    compare_models(export1_hash, export2_hash)
  end

  it "should test that sub namespaces are exported with export_namespace " do

    pending("XML Export has been deprecated in favor of YAML export")
    full_factory_namespace_xml = <<-XML
      <MiqAeDatastore version="1.0">
        <MiqAeClass name="VM" namespace="Factory" display_name="Virtual Machine">
          <MiqAeMethod name="CustomizeRequest" language="ruby" scope="instance" location="inline"><![CDATA[# end]]>    </MiqAeMethod>
          <MiqAeSchema>
            <MiqAeField name="execute" substitute="true" aetype="method" datatype="string" priority="1" message="create">
            </MiqAeField>
          </MiqAeSchema>
        </MiqAeClass>
        <MiqAeClass name="test_class" namespace="Factory/test" display_name="test namespace">
          <MiqAeMethod name="test_method" language="ruby" scope="instance" location="inline"><![CDATA[# end]]>    </MiqAeMethod>
          <MiqAeSchema>
            <MiqAeField name="execute" substitute="true" aetype="method" datatype="string" priority="1" message="create">
            </MiqAeField>
          </MiqAeSchema>
        </MiqAeClass>
      </MiqAeDatastore>
    XML

    MiqAeDatastore.reset
    [MiqAeClass, MiqAeField, MiqAeInstance, MiqAeNamespace, MiqAeMethod, MiqAeValue].each { |k| k.count.should == 0 }

    MiqAeDatastore::Import.load_xml(full_factory_namespace_xml)
    full_factory_namespace_hash = XmlHash.load(full_factory_namespace_xml)
    factory_namespace_export    = MiqAeDatastore.export_namespace("Factory")
    factory_namespace_hash      = XmlHash.load(factory_namespace_export)

    compare_models(full_factory_namespace_hash, factory_namespace_hash)
  end

  it "should test simple namespace export" do
    pending("XML Export has been deprecated in favor of YAML export")
    base_hash = XmlHash.load(@export_xml)

    MiqAeDatastore.reset
    [MiqAeClass, MiqAeField, MiqAeInstance, MiqAeNamespace, MiqAeMethod, MiqAeValue].each { |k| k.count.should == 0 }

    MiqAeDatastore::Import.load_xml(@export_xml)

    export1 = MiqAeDatastore.export_namespace("Factory")
    export1_name = File.join(File.dirname(__FILE__), "test_namespace_export1.xml")
    File.open(export1_name, "w") { |f| f.write(export1) }
    export1_hash = XmlHash.loadFile(export1_name)

    MiqAeDatastore.reset
    [MiqAeClass, MiqAeField, MiqAeInstance, MiqAeNamespace, MiqAeMethod, MiqAeValue].each { |k|  k.count.should == 0 }

    MiqAeDatastore.import(export1_name)
    File.delete(export1_name)
    export2 = MiqAeDatastore.export_namespace("Factory")
    export2_name = File.join(File.dirname(__FILE__), "test_namespace_export2.xml")
    File.open(export2_name, "w") { |f| f.write(export2) }
    export2_hash = XmlHash.loadFile(export2_name)
    File.delete(export2_name)

    compare_models(export1_hash, export2_hash)

  end

  it "should test multi-part namespace export" do
    pending("XML Export has been deprecated in favor of YAML export")
    base_hash = XmlHash.load(@export_xml)

    MiqAeDatastore.reset
    [MiqAeClass, MiqAeField, MiqAeInstance, MiqAeNamespace, MiqAeMethod, MiqAeValue].each { |k| k.count.should == 0 }

    MiqAeDatastore::Import.load_xml(@export_xml)

    export1 = MiqAeDatastore.export_namespace("EVMApplications/Provisioning")
    export1_name = File.join(File.dirname(__FILE__), "test_namespace_export1.xml")
    File.open(export1_name, "w") { |f| f.write(export1) }
    export1_hash = XmlHash.loadFile(export1_name)

    MiqAeDatastore.reset
    [MiqAeClass, MiqAeField, MiqAeInstance, MiqAeNamespace, MiqAeMethod, MiqAeValue].each { |k|  k.count.should == 0 }

    MiqAeDatastore.import(export1_name)
    File.delete(export1_name)
    export2 = MiqAeDatastore.export_namespace("EVMApplications/Provisioning")
    export2_name = File.join(File.dirname(__FILE__), "test_namespace_export2.xml")
    File.open(export2_name, "w") { |f| f.write(export2) }
    export2_hash = XmlHash.loadFile(export2_name)
    File.delete(export2_name)

    compare_models(export1_hash, export2_hash)

  end

  it "should test password import export" do
    pending("XML Export has been deprecated in favor of YAML export")
    @clear_default_password     = 'secret'
    @encrypted_default_password = MiqAePassword.encrypt(@clear_default_password)
    @clear_password             = "Fe@rl3ss"
    @encrypted_password         = MiqAePassword.encrypt(@clear_password)
    @domain = 'PASSWORD_DOMAIN'

    xml = <<-XML
    <MiqAeDatastore version='1.0'>
      <MiqAeClass name="test_default_clear" namespace="evm">
        <MiqAeSchema>
          <MiqAeField name="password" default_value="#{@clear_default_password}" aetype="attribute" datatype="password" />
        </MiqAeSchema>
        <MiqAeInstance name="default"/>
        <MiqAeInstance name="override_clear">
          <MiqAeField name="password">#{@clear_password}</MiqAeField>
        </MiqAeInstance>
        <MiqAeInstance name="override_encrypted">
          <MiqAeField name="password">#{@encrypted_password}</MiqAeField>
        </MiqAeInstance>
      </MiqAeClass>
      <MiqAeClass name="test_default_encrypted" namespace="evm">
        <MiqAeSchema>
          <MiqAeField name="password" default_value="#{@encrypted_default_password}" aetype="attribute" datatype="password" />
        </MiqAeSchema>
        <MiqAeInstance name="default"/>
        <MiqAeInstance name="override_clear">
          <MiqAeField name="password">#{@clear_password}</MiqAeField>
        </MiqAeInstance>
        <MiqAeInstance name="override_encrypted">
          <MiqAeField name="password">#{@encrypted_password}</MiqAeField>
        </MiqAeInstance>
      </MiqAeClass>
    </MiqAeDatastore>
    XML

    base_hash = XmlHash.load(xml)
    MiqAeDatastore::Import.load_xml(xml, @domain)
    ['test_default_clear', 'test_default_encrypted'].each { |cname|
      aec = MiqAeClass.find_by_fqname("#{@domain}/evm/#{cname}")
      aec.should_not be_nil
      aef = aec.ae_fields.detect { |f| f.name == 'password' }
      aef.default_value.should be_encrypted(@default_password)

      aec.ae_instances.each { |aei|
        case aei.name
        when 'default'
          aei.get_field_value(aef).should be_nil
        when 'override_clear', 'override_encrypted'
          aei.get_field_value(aef).should be_encrypted(@clear_password)
        end
      }
    }
    export1_xml  = MiqAeDatastore.export
    export1_hash = XmlHash.load(export1_xml)

    MiqAeDatastore.reset
    MiqAeDatastore::Import.load_xml(export1_xml, @domain)

    ['test_default_clear', 'test_default_encrypted'].each { |cname|
      aec = MiqAeClass.find_by_fqname("#{@domain}/evm/#{cname}")
      aec.should_not be_nil
      aef = aec.ae_fields.detect { |f| f.name == 'password' }
      aef.default_value.should be_encrypted(@default_password)

      aec.ae_instances.each { |aei|
        case aei.name
        when 'default'
          aei.get_field_value(aef).should be_nil
        when 'override_clear', 'override_encrypted'
          aei.get_field_value(aef).should be_encrypted(@clear_password)
        end
      }
    }

    export2_xml  = MiqAeDatastore.export
    export2_hash = XmlHash.load(export2_xml)

    compare_models_with_base(export1_hash, export2_hash, base_hash)

  end

  it "should test model1 xml import" do
    @domain = 'TEST_DOMAIN'
    xml = <<-XML
    <MiqAeDatastore version='1.0'>
      <MiqAeClass name="AUTOMATE" namespace="SYSTEM/EVM">
        <MiqAeSchema>
          <MiqAeField name="discover" aetype="relationship" default_value="" display_name="Discovery Relationships"/>
        </MiqAeSchema>
        <MiqAeInstance name="aevent">
          <MiqAeField name="discover">//system/evm/discover/${//workspace/aevent/type}</MiqAeField>
        </MiqAeInstance>
      </MiqAeClass>
      <MiqAeClass name="DISCOVER" namespace="SYSTEM/EVM">
        <MiqAeSchema>
          <MiqAeField name="os" aetype="attribute" default_value=""/>
        </MiqAeSchema>
        <MiqAeInstance name="vm">
          <MiqAeField name="os">this should be a method to get the OS if it is not in the inbound object</MiqAeField>
        </MiqAeInstance>
        <MiqAeInstance name="host">
          <MiqAeField name="os" value="sometimes"/>
        </MiqAeInstance>
      </MiqAeClass>
    </MiqAeDatastore>
    XML

    MiqAeDatastore::Import.load_xml(xml, @domain)
    MiqAeClass.find_by_fqname("#{@domain}/system/evm/automate").should_not be_nil
    MiqAeClass.find_by_fqname("#{@domain}/system/evm/discover").should_not be_nil
    #TODO: Add more assertions to validate that all contents of import file were correctly imported.

    export = MiqAeDatastore.export
#    puts "XML Export from XML import:\n#{export}"
#    e_xml.should == expected
  end

  it "should test cleanup of temporary file after an unsuccessful import" do
    fd = double(:original_filename => "dummy.zip", :read => "junk", :eof => true, :close => true)
    import_file = File.expand_path(File.join(Rails.root, "tmp/miq_automate_engine", "dummy.zip"))
    expect { MiqAeDatastore.upload(fd, "dummy.zip") }.to raise_error
    File.exist?(import_file).should be_false
  end

  it "should test cleanup of temporary file after a successful import" do
    fd = double(:original_filename => "dummy.zip", :read => "junk", :eof => true, :close => true)
    import_file = File.expand_path(File.join(Rails.root, "tmp/miq_automate_engine", "dummy.zip"))
    MiqAeDatastore.should_receive(:import_yaml_zip).with(import_file, "*").once
    MiqAeDatastore.upload(fd, "dummy.zip")
    File.exist?(import_file).should be_false
  end

  it "#reset_default_namespace" do
    MiqAeDatastore.reset_default_namespace

    MiqAeNamespace.first.name.should eq("$")
    MiqAeClass.first.name.should     eq("Object")
    MiqAeMethod.count.should         eq(3)
  end

  private

  def sanitize_miq_ae_fields(fields)
    unless fields.nil?
      for i in 1..(fields.length) do
        f = fields[i-1]
        f["message"]       = @defaults_miq_ae_field[:message]      if f["message"].nil?
        f["substitute"]    = @defaults_miq_ae_field[:substitute]   if f["substitute"].blank?
        f["priority"]      = i.to_s                                if f["priority"].nil?
        unless f["collect"].blank?
          f["collect"] = f["collect"].first["content"]             if f["collect"].kind_of?(Array)
          f["collect"] = REXML::Text.unnormalize(f["collect"].strip)
        end
        ['on_entry', 'on_exit', 'on_error'].each { |k| f[k] = REXML::Text.unnormalize(f[k].strip) unless f[k].blank? }
        f["default_value"] = f.delete("content").strip             unless f["content"].nil?
        f["default_value"] = ""                                    if f["default_value"].nil?
        f["default_value"] = MiqAePassword.encrypt(f["default_value"]) if f["datatype"] == 'password'
        fields[i-1] = f
      end
    end
    fields
  end

  def compare_models(hash1, hash2)
    c1 = hash1.to_h(:symbols => false)["MiqAeClass"].sort_by { |a| [a['namespace'], a['name']] }
    c2 = hash2.to_h(:symbols => false)["MiqAeClass"].sort_by { |a| [a['namespace'], a['name']] }

    while c1.length > 0 do
      aec1 = c1.pop
      aec2 = c2.pop

      schema1 = aec1.delete("MiqAeSchema")
      schema2 = aec2.delete("MiqAeSchema")

      unless schema1.nil? || schema2.nil?
        f1 = sanitize_miq_ae_fields(schema1.first.delete("MiqAeField"))
        f2 = sanitize_miq_ae_fields(schema2.first.delete("MiqAeField"))
      end

      schema1.should == schema2

      unless f1.nil? || f2.nil?
        f1.length.should == f2.length

        [f1, f2].each { |fields| fields.sort! { |a,b| a['name'] <=> b['name'] } }

        for i in 1..(f1.length) do
          field1 = f1[i-1]
          field2 = f2[i-1]

          field1.keys.sort.should == field2.keys.sort

          field1.should == field2
        end
      end

      unless schema1.nil? || schema2.nil?
        f1.should == f2
      end

      methods1 = aec1.delete("MiqAeMethod")
      methods2 = aec2.delete("MiqAeMethod")

      unless methods1.nil? || methods2.nil?
        methods1.length.should == methods2.length

        [methods1, methods2].each do |methods|
          for i in 1..(methods.length) do
            method = methods[i-1]
            method["content"].strip!            unless method["content"].nil?
            methods[i-1] = method
          end
        end

        [methods1, methods2].each { |methods| methods.sort! { |a,b| a['name'] <=> b['name'] } }

        for i in 1..(methods1.length) do
          method1 = methods1[i-1]
          method2 = methods2[i-1]

          mf1      = sanitize_miq_ae_fields(method1.delete("MiqAeField"))
          mf2      = sanitize_miq_ae_fields(method2.delete("MiqAeField"))
          mf1.should == mf2

          method1.delete("content") if method1.has_key?("content") && method1["content"].strip == ""
          method2.delete("content") if method2.has_key?("content") && method2["content"].strip == ""

          method1.should == method2
        end
      end

      methods1.should == methods2

      instances1 = aec1.delete("MiqAeInstance")
      instances2 = aec2.delete("MiqAeInstance")

      unless instances1.nil? || instances2.nil?
        instances1.length.should == instances2.length

        [instances1, instances2].each do |instances|
          for i in 1..(instances.length) do
            inst = instances[i-1]
            values = inst["MiqAeField"]
            next if values.nil?
            for x in 1..(values.length) do
              value = values[x-1]
              value["content"].strip! unless value["content"].nil?
              values[x-1] = value
            end
            inst["MiqAeField"] = values.sort { |a,b| a['name'] <=> b['name'] }
            instances[i-1] = inst
          end
        end

        [instances1, instances2].each { |instances| instances.sort! { |a,b| a['name'] <=> b['name'] } }

        for i in 1..(instances1.length) do
          i1 = instances1[i-1]
          i2 = instances2[i-1]
          i1.should == i2
        end
      end

      instances1.should == instances2
      aec1.should == aec2
    end
  end


  def compare_models_with_base(hash1, hash2, base)

    c1 = hash1.to_h(:symbols=>false)["MiqAeClass"].sort { |a,b| a['name'] <=> b['name'] }
    c2 = hash2.to_h(:symbols=>false)["MiqAeClass"].sort { |a,b| a['name'] <=> b['name'] }
    b1 = base.to_h(:symbols=>false)["MiqAeClass"].sort { |a,b| a['name'] <=> b['name'] }


    while c1.length > 0 do
      aec1 = c1.pop
      aec2 = c2.pop
      aecb = b1.pop

      schema1 = aec1.delete("MiqAeSchema")
      schema2 = aec2.delete("MiqAeSchema")
      schemab = aecb.delete("MiqAeSchema")

      unless schema1.nil? || schema2.nil? || schemab.nil?
        f1 = sanitize_miq_ae_fields(schema1.first.delete("MiqAeField").sort { |a,b| a['name'] <=> b['name'] })
        f2 = sanitize_miq_ae_fields(schema2.first.delete("MiqAeField").sort { |a,b| a['name'] <=> b['name'] })
        fb = sanitize_miq_ae_fields(schemab.first.delete("MiqAeField").sort { |a,b| a['name'] <=> b['name'] })
      end

      schema1.should == schema2
      schema1.should == schemab

      unless f1.nil? || f2.nil? || fb.nil?
        f1.length.should == f2.length
        f1.length.should == fb.length
        f1.length.should == 1

        field1 = f1.first
        field2 = f2.first
        fieldb = fb.first

        field1.keys.sort.should == field2.keys.sort
        field1.keys.sort.should == fieldb.keys.sort

        defaultb = fieldb.delete('default_value')
        default1 = field1.delete('default_value')
        default2 = field2.delete('default_value')

        field1.should == field2
        field1.should == fieldb

        default1.should == default2
        default1.should be_encrypted(MiqPassword.try_decrypt(defaultb))
        case aec1['name']
        when 'test_default_clear', 'test_default_encrypted'
          defaultb.should be_encrypted(@clear_default_password)
        end
      end

      unless schema1.nil? || schema2.nil? || schemab.nil?
        f1.should == f2
        f1.should == fb
      end

      instances1 = aec1.delete("MiqAeInstance").sort { |a,b| a['name'] <=> b['name'] }
      instances2 = aec2.delete("MiqAeInstance").sort { |a,b| a['name'] <=> b['name'] }
      instancesb = aecb.delete("MiqAeInstance").sort { |a,b| a['name'] <=> b['name'] }

      unless instances1.nil? || instances2.nil? || instancesb.nil?
        instances1.length.should == instances2.length
        instances1.length.should == instancesb.length

        [instances1, instances2, instancesb].each do |instances|
          for i in 1..(instances.length) do
            inst = instances[i-1]
            values = inst["MiqAeField"]
            next if values.nil?
            for x in 1..(values.length) do
              value = values[x-1]
              value["content"].strip! unless value["content"].nil?
              values[x-1] = value
            end
            inst["MiqAeField"] = values.sort { |a,b| a['name'] <=> b['name'] }
            instances[i-1] = inst
          end
        end

        [instances1, instances2, instancesb].each { |instances| instances.sort! { |a,b| a['name'] <=> b['name'] } }

        for i in 1..(instances1.length) do
          i1 = instances1[i-1]
          i2 = instances2[i-1]
          ib = instancesb[i-1]

          i1.should == i2

          if i1['name'] == 'default'
            i1.should == ib
          else
            fb = ib.delete('MiqAeField')
            f1 = i1.delete('MiqAeField')
            f2 = i2.delete('MiqAeField')

            vb = fb.first['content']
            v1 = f1.first['content']
            v2 = f2.first['content']

            v1.should == v2
            v1.should be_encrypted(MiqPassword.try_decrypt(vb))
            case i1['name']
            when 'override_clear'
              vb.should == @clear_password
            when 'overrride_encrypted'
              vb.should == be_encrypted(@clear_password)
            end
          end
        end
      end

      instances1.should == instances2
      instances1.should == instancesb

      aec1.should == aec2
      aec1.should == aecb
    end
  end

  # Inital round of refactoring resulting in 2 similar methods, compare_models_with_base and compare_models_with_base_extended.
  def compare_models_with_base_extended(hash1, hash2, base)

    c1 = hash1.to_h(:symbols=>false)["MiqAeClass"].sort_by { |a| [ a['namespace'], a['name'] ]}
    c2 = hash2.to_h(:symbols=>false)["MiqAeClass"].sort_by { |a| [ a['namespace'], a['name'] ]}
    b1 = base.to_h(:symbols=>false)["MiqAeClass"].sort_by { |a| [ a['namespace'], a['name'] ]}
    base.to_h(:symbols=>false)["MiqAeClass"].length.should == c1.length
    c2.length.should == c1.length
    b1.length.should == c1.length

    while c1.length > 0 do
      aec1 = c1.pop
      aec2 = c2.pop
      aecb = b1.pop
      # puts "comparing class: #{aec1["namespace"]}/#{aec1["name"]}"

      schema1 = aec1.delete("MiqAeSchema")
      schema2 = aec2.delete("MiqAeSchema")
      schemab = aecb.delete("MiqAeSchema")

      unless schema1.nil? || schema2.nil? || schemab.nil?
        f1 = sanitize_miq_ae_fields(schema1.first.delete("MiqAeField"))
        f2 = sanitize_miq_ae_fields(schema2.first.delete("MiqAeField"))
        fb = sanitize_miq_ae_fields(schemab.first.delete("MiqAeField"))
      end

      schema1.should == schema2
      schema1.should == schemab

      unless f1.nil? || f2.nil? || fb.nil?
        f1.length.should == f2.length
        f1.length.should == fb.length

        [f1, f2, fb].each { |fields| fields.sort! { |a,b| a['name'] <=> b['name'] } }

        for i in 1..(f1.length) do
          field1 = f1[i-1]
          field2 = f2[i-1]
          fieldb = fb[i-1]

          field1.keys.sort.should == field2.keys.sort
          field1.keys.sort.should == fieldb.keys.sort

          field1.should == field2
          field1.should == fieldb
        end
      end

      unless schema1.nil? || schema2.nil? || schemab.nil?
        f1.should == f2
        f1.should == fb
      end

      methods1 = aec1.delete("MiqAeMethod")
      methods2 = aec2.delete("MiqAeMethod")
      methodsb = aecb.delete("MiqAeMethod")

      unless methods1.nil? || methods2.nil? || methodsb.nil?
        methods1.length.should == methods2.length
        methods1.length.should == methodsb.length

        [methods1, methods2, methodsb].each do |methods|
          for i in 1..(methods.length) do
            method = methods[i-1]
            method["content"].strip!            unless method["content"].nil?
            methods[i-1] = method
          end
        end

        [methods1, methods2, methodsb].each { |methods| methods.sort! { |a,b| a['name'] <=> b['name'] } }

        for i in 1..(methods1.length) do
          method1 = methods1[i-1]
          method2 = methods2[i-1]
          methodb = methodsb[i-1]

          mf1      = sanitize_miq_ae_fields(method1.delete("MiqAeField"))
          mf2      = sanitize_miq_ae_fields(method2.delete("MiqAeField"))
          mfb      = sanitize_miq_ae_fields(methodb.delete("MiqAeField"))
          mf1.should == mf2
          mf1.should == mfb

          method1.delete("content") if method1.has_key?("content") && method1["content"].strip == ""
          method2.delete("content") if method2.has_key?("content") && method2["content"].strip == ""
          methodb.delete("content") if methodb.has_key?("content") && methodb["content"].strip == ""

          method1.should == method2
          method1.should == methodb
        end
      end

      methods1.should == methods2
      methods1.should == methodsb

      instances1 = aec1.delete("MiqAeInstance")
      instances2 = aec2.delete("MiqAeInstance")
      instancesb = aecb.delete("MiqAeInstance")

      unless instances1.nil? || instances2.nil? || instancesb.nil?
        instances1.length.should == instances2.length
        instances1.length.should == instancesb.length

        [instances1, instances2, instancesb].each do |instances|
          for i in 1..(instances.length) do
            inst = instances[i-1]
            values = inst["MiqAeField"]
            next if values.nil?
            for x in 1..(values.length) do
              value = values[x-1]
              value["content"].strip! unless value["content"].nil?
              values[x-1] = value
            end
            inst["MiqAeField"] = values.sort { |a,b| a['name'] <=> b['name'] }
            instances[i-1] = inst
          end
        end

        [instances1, instances2, instancesb].each { |instances| instances.sort! { |a,b| a['name'] <=> b['name'] } }

        for i in 1..(instances1.length) do
          i1 = instances1[i-1]
          i2 = instances2[i-1]
          ib = instancesb[i-1]
          i1.should == i2
          i1.should == ib
        end
      end

      instances1.should == instances2
      instances1.should == instancesb

      aec1.should == aec2
      aec1.should == aecb
    end
  end

end

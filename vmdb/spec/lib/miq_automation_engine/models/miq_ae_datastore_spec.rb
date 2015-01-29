require "spec_helper"
require 'miq_ae_yaml_import_zipfs'

describe MiqAeDatastore do
  before(:each) do
    @ver_fname = File.expand_path(File.join(File.dirname(__FILE__), "version.xml"))

    @export_xml = <<-XML
      <MiqAeDatastore version="1.0">
        <MiqAeClass name="VM" namespace="Factory" display_name="Virtual Machine">
          <MiqAeMethod name="CustomizeRequest" language="ruby" scope="instance" location="inline"><![CDATA[# end]]>
          </MiqAeMethod>
          <MiqAeSchema>
            <MiqAeField name="execute" substitute="true" aetype="method" datatype="string" priority="1" message="create">
            </MiqAeField>
          </MiqAeSchema>
        </MiqAeClass>
        <MiqAeClass name="test_class" namespace="Factory/test" display_name="test namespace">
          <MiqAeMethod name="test_method" language="ruby" scope="instance" location="inline"><![CDATA[# end]]>
          </MiqAeMethod>
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

  def setup_version_xml(v)
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
    setup_version_xml(MiqAeDatastore::XML_VERSION_MIN_SUPPORTED)
    -> { MiqAeDatastore.import(@ver_fname) }.should_not raise_error

    MiqAeDatastore.reset
    setup_version_xml(MiqAeDatastore::XML_VERSION_MIN_SUPPORTED.to_f + 0.1)
    -> { MiqAeDatastore.import(@ver_fname) }.should_not raise_error

    MiqAeDatastore.reset
    setup_version_xml(MiqAeDatastore::XML_VERSION_MIN_SUPPORTED.to_f - 0.1)
    -> { MiqAeDatastore.import(@ver_fname) }.should raise_error(RuntimeError)

    MiqAeDatastore.reset
    setup_version_xml(nil)
    -> { MiqAeDatastore.import(@ver_fname) }.should raise_error(RuntimeError)
  end

  it ".backup" do
    MiqAeYamlExportZipfs.any_instance.should_receive(:export).once
    MiqAeDatastore.backup('zip_file'  => 'dummy', 'overwrite' => true)
  end

  it ".upload" do
    fd = double(:original_filename => "dummy.zip", :read => "junk", :eof => true, :close => true)
    import_file = File.expand_path(File.join(Rails.root, "tmp/miq_automate_engine", "dummy.zip"))
    MiqAeDatastore.should_receive(:import_yaml_zip).with(import_file, "*").once

    MiqAeDatastore.upload(fd, "dummy.zip")
  end

  it ".reset_default_namespace" do
    MiqAeDatastore.reset_default_namespace
    default_ns = MiqAeDomain.first || MiqAeNamespace.first
    default_ns.name.should eq("$")
    MiqAeClass.first.name.should     eq("Object")
    MiqAeMethod.count.should         eq(3)
  end

  it "temporary file cleanup for unsuccessful import" do
    fd = double(:original_filename => "dummy.zip", :read => "junk", :eof => true, :close => true)
    import_file = File.expand_path(File.join(Rails.root, "tmp/miq_automate_engine", "dummy.zip"))
    expect { MiqAeDatastore.upload(fd, "dummy.zip") }.to raise_error
    File.exist?(import_file).should be_false
  end

  it "temporary file cleanup for successful import" do
    fd = double(:original_filename => "dummy.zip", :read => "junk", :eof => true, :close => true)
    import_file = File.expand_path(File.join(Rails.root, "tmp/miq_automate_engine", "dummy.zip"))
    MiqAeDatastore.should_receive(:import_yaml_zip).with(import_file, "*").once
    MiqAeDatastore.upload(fd, "dummy.zip")
    File.exist?(import_file).should be_false
  end

  describe "restore" do

    let(:miq_ae_yaml_import_zipfs)  { instance_double("MiqAeYamlImportZipfs") }
    let(:dummy_zipfile) { File.expand_path(File.join(File.dirname(__FILE__), "/miq_ae_datastore/data/dummy.zip")) }

    before do
      MiqAeImport.stub(:new).and_return(miq_ae_yaml_import_zipfs)
      miq_ae_yaml_import_zipfs.stub(:import)
    end

    it "validate arguments" do
      options_hash = {'restore' => true, 'preview' => false, 'zip_file' => dummy_zipfile}
      MiqAeImport.should_receive(:new).with("*", options_hash)
      MiqAeDatastore.restore(dummy_zipfile)
    end

    it "imports" do
      miq_ae_yaml_import_zipfs.should_receive(:import).once
      MiqAeDatastore.restore(dummy_zipfile)
    end
  end

end

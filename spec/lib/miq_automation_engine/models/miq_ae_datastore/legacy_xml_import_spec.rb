describe "LegacyXMLImport" do
  let(:xml) do
    %(
    <MiqAeDatastore version='1.0'>
      <MiqAeClass name="AUTOMATE" namespace="EVM">
        <MiqAeSchema>
          <MiqAeField name="method1"  aetype="method"/>
        </MiqAeSchema>
        <MiqAeMethod name="test" language="ruby" location="inline" scope="instance">
         <![CDATA[
          ]]>
         </MiqAeMethod>
         <MiqAeInstance name="test1">
           <MiqAeField name="method1">test</MiqAeField>
         </MiqAeInstance>
       </MiqAeClass>
    </MiqAeDatastore>
    )
  end
  before(:each) do
    Tenant.seed
    # hide deprecation warning
    expect(MiqAeDatastore).to receive(:xml_deprecated_warning)
    MiqAeDatastore::Import.load_xml(xml)
  end

  it "Check the tenant" do
    expect(MiqAeDomain.first.tenant_id).to eql(Tenant.root_tenant.id)
  end
end

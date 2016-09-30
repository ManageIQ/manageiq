describe "parse_event_stream" do
  let(:inst)          { "/System/Process/parse_event_stream" }
  let(:user)          { FactoryGirl.create(:user_with_group) }
  let(:ems)           { FactoryGirl.create(:ems_vmware_with_authentication, :zone => FactoryGirl.create(:zone)) }
  let(:vm)            { FactoryGirl.create(:vm_vmware, :ext_management_system => ems) }
  let(:miq_event)     { FactoryGirl.create(:miq_event, :event_type => "some_event") }
  let(:request_event) { FactoryGirl.create(:request_event) }
  let(:custom_event)  { FactoryGirl.create(:custom_event) }
  let(:ems_event) do
    FactoryGirl.create(:ems_event, :vm_or_template => vm, :ext_management_system => ems)
  end
  let(:ems_event_no_source) do
    FactoryGirl.create(:ems_event, :vm_or_template => vm, :ext_management_system => nil)
  end

  it "invalid event stream" do
    expect { MiqAeEngine.instantiate(inst, user) }
      .to raise_error(MiqAeException::AbortInstantiation, "Event Stream object not found")
  end

  it "for emsevents" do
    ws = MiqAeEngine.instantiate("#{inst}?EmsEvent::event_stream=#{ems_event.id}", user)
    expect(ws.root["event_path"]).to eq("/Vmware/EMSEvent/infrastructure/Event")
  end

  it "for emsevents with an invalid ems" do
    expect { MiqAeEngine.instantiate("#{inst}?EmsEvent::event_stream=#{ems_event_no_source.id}", user) }
      .to raise_error(MiqAeException::AbortInstantiation, "EMS event - Invalid provider")
  end

  it "for miqevents" do
    ws = MiqAeEngine.instantiate("#{inst}?MiqEvent::event_stream=#{miq_event.id}", user)
    expect(ws.root["event_path"]).to eq("/System/Event/MiqEvent/")
  end

  it "for request events" do
    ws = MiqAeEngine.instantiate("#{inst}?RequestEvent::event_stream=#{request_event.id}", user)
    expect(ws.root["event_path"]).to eq("/System/Event/RequestEvent/")
  end

  it "custom events" do
    ws = MiqAeEngine.instantiate("#{inst}?CustomEvent::event_stream=#{custom_event.id}", user)
    expect(ws.root["event_path"]).to eq("/System/Event/CustomEvent/")
  end
end

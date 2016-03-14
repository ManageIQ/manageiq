describe "ops/_zone_form.html.haml" do
  before do
    assign(:sb, :active_tab => "settings_evm_servers")
    @selected_zone = FactoryGirl.create(:zone, :name => 'One Zone', :description => " One Description", :settings =>
                                                {:proxy_server_ip => '1.2.3.4', :concurrent_vm_scans => 0, :ntp => {:server => ['Server 1']}})
    @servers = []
  end

  context "zone selected" do
    before(:each) do
      @zone = FactoryGirl.create(:zone)
      @edit = {:zone_id => nil,
               :new => {:name => nil,
                        :description => nil,
                        :proxy_server_ip => nil,
                        :concurrent_vm_scans => '0',
                        :userid => nil,
                        :password => nil,
                        :verify => nil,
                        :ntp => {:server =>[]}},
               :current => {:name => nil,
                            :description => nil,
                            :proxy_server_ip => nil,
                            :concurrent_vm_scans => '0',
                            :userid => nil,
                            :password => nil,
                            :verify => nil,
                            :ntp => { :server => []}},
               :key => 'zone_edit__new',
               :default_verify_status => true}
    end
    it "should  show zone information" do
      render :partial => "ops/zone_form"
      expect(response.body).to include('Name')
      expect(response.body).to include('Description')
      expect(response.body).to include('SmartProxy Server IP')
      expect(response.body).to include('NTP Servers')
      expect(response.body).to include('Max Active VM Scans')
    end

    it "name should not be disabled on adding a zone" do
      @edit[:current][:name] = 'One Zone'
      @zone.name = nil
      @zone.id = nil
      render :partial => "ops/zone_form"
      expect(response.body).to include('<input type="text" name="name" id="name" maxlength="50" class="form-control" data-miq_observe="{&quot;interval&quot;:&quot;.5&quot;,&quot;url&quot;:&quot;/ops/zone_field_changed/new&quot;}" />')
    end

    it "name should be disabled when editing an existing zone" do
      @edit[:current][:name] = 'Test Zone'
      @zone.name = 'Test Zone'
      @zone.id = nil
      render :partial => "ops/zone_form"
      expect(response.body).to include('<input type="text" name="name" id="name" maxlength="50" disabled="disabled" class="form-control" data-miq_observe="{&quot;interval&quot;:&quot;.5&quot;,&quot;url&quot;:&quot;/ops/zone_field_changed/new&quot;}" />')
    end
  end
end

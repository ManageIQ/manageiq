require "spec_helper"

describe 'miq_request/_prov_vm_grid.html.haml' do
  context 'check for links' do
    before(:each) do
      @vm_user = FactoryGirl.create(:user, :role => "vm_user")
      @vms = [FactoryGirl.create(:vm_vmware)]
      edit = {:req_id => "foo",
              :new => {},
              :wf => FactoryGirl.create(:miq_provision_workflow,:requester => @vm_user),
              :vm_sortcol => 'name',
              :vm_sortdir => 'ASC',
              :vm_columns => %w(name),
              :vm_headers => {"name"=>"Name"}
             }
      view.instance_variable_set(:@edit, edit)
      view.instance_variable_set(:@vms, @vms)
    end

    it 'validates links in vm grid' do
      login_as @vm_user
      render :partial => "miq_request/prov_vm_grid.html.haml", :locals => {:field_id => 'service__src_vm_id'}
      expect(response).to have_selector("//tr[@onclick=\"miqAjax('/miq_request/prov_field_changed/?service__src_vm_id=__VM__NONE__&id=foo');\"]")
      expect(response).to have_selector("//tr[@onclick=\"miqAjax('/miq_request/prov_field_changed/?service__src_vm_id=#{@vms.first.id}&id=foo');\"]")
    end
  end
end

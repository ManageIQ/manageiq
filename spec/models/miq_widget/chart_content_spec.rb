RSpec.describe "Widget Chart Content" do
  let(:widget) { MiqWidget.find_by(:description => "chart_vendor_and_guest_os") }
  before do
    _guid, _server, _zone = EvmSpecHelper.create_guid_miq_server_zone

    MiqReport.seed_report("Vendor and Guest OS")
    MiqWidget.seed_widget("chart_vendor_and_guest_os")

    @role  = FactoryBot.create(:miq_user_role)
    @group = FactoryBot.create(:miq_group, :miq_user_role => @role)
    @user  = FactoryBot.create(:user, :miq_groups => [@group])

    5.times do |i|
      vm = FactoryBot.build(:vm_vmware)
      vm.evm_owner_id = @user.id           if i > 2
      vm.miq_group_id = @user.current_group.id if vm.evm_owner_id || (i > 1)
      vm.save
    end
  end

  it "#generate_content_for_user" do
    content = widget.generate_one_content_for_user(@group, @user)
    expect(content.miq_report_result.html_rows.count { |c| c.match("<td>VMware</td>") }).to eq(ManageIQ::Providers::Vmware::InfraManager::Vm.count)
    expect(widget.contents_for_user(@user)).to eq(content)
  end

  it "#generate_content for group" do
    content = widget.generate_one_content_for_group(@user.current_group, @user.get_timezone)
    expect(content.miq_report_result.html_rows.count { |c| c.match("<td>VMware</td>") }).to eq(ManageIQ::Providers::Vmware::InfraManager::Vm.count)
    expect(widget.contents_for_user(@user)).to eq(content)
  end

  it "#generate_content for self_service user" do
    @role.update(:settings => {:restrictions => {:vms => :user_or_group}})
    content = widget.generate_one_content_for_user(@group, @user)
    expect(content.miq_report_result.html_rows.count { |c| c.match("<td>VMware</td>") }).to eq(3)
    expect(widget.contents_for_user(@user)).to eq(content)
  end

  it "#generate_content for limited_self_service user" do
    @role.update(:settings => {:restrictions => {:vms => :user}})
    content = widget.generate_one_content_for_user(@group, @user)
    expect(content.miq_report_result.html_rows.count { |c| c.match("<td>VMware</td>") }).to eq(2)
    expect(widget.contents_for_user(@user)).to eq(content)
  end

  it "#generate_content for self_service_group" do
    @role.update(:settings => {:restrictions => {:vms => :user_or_group}})
    content = widget.generate_one_content_for_group(@user.current_group, @user.get_timezone)
    expect(content.miq_report_result.html_rows.count { |c| c.match("<td>VMware</td>") }).to eq(3)
    expect(widget.contents_for_user(@user)).to eq(content)
  end

  it "#generate_content for limited_self_service_group" do
    @role.update(:settings => {:restrictions => {:vms => :user}})
    content = widget.generate_one_content_for_group(@user.current_group, @user.get_timezone)
    expect(content.miq_report_result.html_rows.count { |c| c.match("<td>VMware</td>") }).to eq(3)
    expect(widget.contents_for_user(@user)).to eq(content)
  end

  it '#generate returns valid data' do
    content = widget.generate_one_content_for_user(@group, @user)
    expect(ManageIQ::Reporting::Charting.data_ok? content.contents).to eq(true)
  end
end

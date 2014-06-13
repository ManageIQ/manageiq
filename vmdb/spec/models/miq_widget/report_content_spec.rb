require "spec_helper"

describe "Widget Report Content" do
  let(:widget) { MiqWidget.sync_from_hash(YAML.load('
    description: report_vendor_and_guest_os
    title: Vendor and Guest OS
    content_type: report
    options:
      :col_order:
        - name
        - vendor
      :row_count: 10
    visibility:
      :roles:
      - _ALL_
    resource_name: Vendor and Guest OS
    resource_type: MiqReport
    enabled: true
    read_only: true
  '))}

  before(:each) do
    MiqRegion.seed
    RssFeed.sync_from_yml_dir
    MiqReport.seed_report("Vendor and Guest OS")

    EvmSpecHelper.create_guid_miq_server_zone
    @admin       = FactoryGirl.create(:user_admin)
    @admin_group = @admin.current_group
    10.times do |i|
      FactoryGirl.create(:vm_vmware)
    end
  end

  it "#generate_content_for_user" do
    content = widget.generate_one_content_for_user(@admin_group, @admin)
    content.should be_kind_of MiqWidgetContent
    content.contents.scan("</tr>").length.should == widget.options[:row_count] + 1
    content.contents.scan("</td>").length.should == widget.options[:row_count] * widget.options[:col_order].length
    content.contents.scan("</th>").length.should == widget.options[:col_order].length
    content.miq_report_result.html_rows(:offset => 0, :limit => 1).first.scan("</td>").length.should == widget.resource.col_order.length
    content.miq_report_result.html_rows.count {|c| c.match("<td>VMware</td>") }.should == VmVmware.count
    content.contents.should match "<tr><th class='title'>Name</th><th class='title'>Container</th></tr>"
    widget.contents_for_user(@admin).should == content
  end

  it "#generate_content_for_group" do
    content = widget.generate_one_content_for_group(@admin.current_group, @admin.get_timezone)
    content.should be_kind_of MiqWidgetContent
    content.contents.scan("</tr>").length.should == widget.options[:row_count] + 1
    content.contents.scan("</td>").length.should == widget.options[:row_count] * widget.options[:col_order].length
    content.contents.scan("</th>").length.should == widget.options[:col_order].length
    content.miq_report_result.html_rows(:offset => 0, :limit => 1).first.scan("</td>").length.should == widget.resource.col_order.length
    content.miq_report_result.html_rows.count {|c| c.match("<td>VMware</td>") }.should == VmVmware.count
    content.contents.should match "<tr><th class='title'>Name</th><th class='title'>Container</th></tr>"
    widget.contents_for_user(@admin).should == content
  end

  it "should work for self service users (FB#17125)" do
    self_service_role = FactoryGirl.create(
      :miq_user_role,
      :name               => "ss_role",
      :settings           => {:restrictions => {:vms => :user_or_group}}
    )

    self_service_group = FactoryGirl.create(
      :miq_group,
      :description        => "EvmGroup-self_service",
      :miq_user_role      => self_service_role
    )
    user2   = FactoryGirl.create(:user, :userid => "user2", :miq_groups => [self_service_group])

    report = widget.generate_report(self_service_group, user2)
    content = MiqWidget::ReportContent.new(:report => report, :resource => widget.resource, :timezone => "UTC", :widget_options => widget.options)

    lambda { content.generate(user2)}.should_not raise_error
  end

end

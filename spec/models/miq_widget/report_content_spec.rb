describe MiqWidget, "::ReportContent" do
  let(:vm_count) { 2 }
  let(:widget) do
    MiqWidget.sync_from_hash(YAML.load("
    description: report_vendor_and_guest_os
    title: Vendor and Guest OS
    content_type: report
    options:
      :col_order:
        - name
        - vendor_display
      :row_count: #{vm_count}
    visibility:
      :roles:
      - _ALL_
    resource_name: Vendor and Guest OS
    resource_type: MiqReport
    enabled: true
    read_only: true
  "))
  end

  before do
    MiqReport.seed_report("Vendor and Guest OS")

    EvmSpecHelper.create_guid_miq_server_zone
    @admin       = FactoryGirl.create(:user_admin)
    @admin_group = @admin.current_group
    vm_count.times { FactoryGirl.create(:vm_vmware) }
  end

  it "#generate_one_content_for_user" do
    content = widget.generate_one_content_for_user(@admin_group, @admin)
    expect(content).to be_kind_of MiqWidgetContent
    expect(content.contents.scan("</tr>").length).to eq(widget.options[:row_count] + 1)
    expect(content.contents.scan("</td>").length).to eq(widget.options[:row_count] * widget.options[:col_order].length)
    expect(content.contents.scan("</th>").length).to eq(widget.options[:col_order].length)
    expect(content.miq_report_result.html_rows(:offset => 0, :limit => 1).first.scan("</td>").length).to eq(widget.resource.col_order.length)
    expect(content.miq_report_result.html_rows.count { |c| c.match("<td>VMware</td>") }).to eq(vm_count)
    expect(content.contents).to match "<tr><th>Name</th><th>Container</th></tr>"
    expect(widget.contents_for_user(@admin)).to eq(content)
  end

  it "#generate_one_content_for_group" do
    content = widget.generate_one_content_for_group(@admin.current_group, @admin.get_timezone)
    expect(content).to be_kind_of MiqWidgetContent
    expect(content.contents.scan("</tr>").length).to eq(widget.options[:row_count] + 1)
    expect(content.contents.scan("</td>").length).to eq(widget.options[:row_count] * widget.options[:col_order].length)
    expect(content.contents.scan("</th>").length).to eq(widget.options[:col_order].length)
    expect(content.miq_report_result.html_rows(:offset => 0, :limit => 1).first.scan("</td>").length).to eq(widget.resource.col_order.length)
    expect(content.miq_report_result.html_rows.count { |c| c.match("<td>VMware</td>") }).to eq(vm_count)
    expect(content.contents).to match "<tr><th>Name</th><th>Container</th></tr>"
    expect(widget.contents_for_user(@admin)).to eq(content)
  end

  it "#generate with self service user" do
    self_service_role = FactoryGirl.create(
      :miq_user_role,
      :name     => "ss_role",
      :settings => {:restrictions => {:vms => :user_or_group}}
    )

    self_service_group = FactoryGirl.create(
      :miq_group,
      :description   => "EvmGroup-self_service",
      :miq_user_role => self_service_role
    )
    user2   = FactoryGirl.create(:user, :miq_groups => [self_service_group])
    report  = widget.generate_report(self_service_group, user2)
    content = MiqWidget::ReportContent.new(:report => report, :resource => widget.resource, :timezone => "UTC", :widget_options => widget.options)

    expect { content.generate(user2) }.not_to raise_error
  end
end

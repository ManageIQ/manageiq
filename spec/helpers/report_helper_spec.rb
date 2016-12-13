def create_user_with_group(user_id, group_name, role)
  group = FactoryGirl.create(:miq_group, :miq_user_role => role, :description => group_name)
  FactoryGirl.create(:user, :userid => user_id, :miq_groups => [group])
end

def create_and_generate_report_for_user(report_name, user_id)
  MiqReport.seed_report(report_name)
  @rpt = MiqReport.where(:name => report_name).last
  @rpt.generate_table(:userid => user_id)
  report_result = @rpt.build_create_results(:userid => user_id)
  report_result.reload
  @rpt
end

describe ReportHelper do
  context '#chart_fields_options' do
    it 'should return fields with models and aggregate functions from summary when "Show Sort Breaks" is not "No"' do
      @edit = {
        :new => {
          :group       => "Yes",
          :col_options => {"name" => {:break_label => "Cloud/Infrastructure Provider : Name: "}, "mem_cpu" => {:grouping => [:total]}, "allocated_disk_storage" => {:grouping => [:total]}},
          :model       => "Vm",
          :headers     => {"Vm.ext_management_system-name" => "Cloud/Infrastructure Provider Name", "Vm-os_image_name" => "OS Name", "Vm-mem_cpu" => "Memory", "Vm-allocated_disk_storage" => "Allocated Disk Storage"},
          :field_order => [
            ["Cloud/Infrastructure Provider : Name", "Vm.ext_management_system-name"],
            [" OS Name", "Vm-os_image_name"],
            [" Memory", "Vm-mem_cpu"],
            [" Allocated Disk Storage", "Vm-allocated_disk_storage"]
          ]
        }
      }

      options = chart_fields_options
      expected_array = [
        ["Nothing selected", nil],
        ["Memory (Total)", "Vm-mem_cpu:total"],
        ["Allocated Disk Storage (Total)", "Vm-allocated_disk_storage:total"]
      ]

      expect(options).to eq(expected_array)
    end

    it 'should return numeric fields from report with models when "Show Sort Breaks" is "No"' do
      @edit = {
        :new => {
          :group       => "No",
          :model       => "Vm",
          :field_order => [
            ["Cloud/Infrastructure Provider : Name", "Vm.ext_management_system-name"],
            [" OS Name", "Vm-os_image_name"],
            [" Memory", "Vm-mem_cpu"],
            [" Allocated Disk Storage", "Vm-allocated_disk_storage"]
          ]
        }
      }

      options = chart_fields_options

      expected_array = [
        ["Nothing selected", nil],
        [" Memory", "Vm-mem_cpu"],
        [" Allocated Disk Storage", "Vm-allocated_disk_storage"]
      ]

      expect(options).to eq(expected_array)
    end
  end
end

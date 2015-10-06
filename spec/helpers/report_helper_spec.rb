require "spec_helper"

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

      expect(options).to eq([["Memory (Total)", "Vm-mem_cpu:total"], ["Allocated Disk Storage (Total)", "Vm-allocated_disk_storage:total"]])
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

      expect(options).to eq([[" Memory", "Vm-mem_cpu"], [" Allocated Disk Storage", "Vm-allocated_disk_storage"]])
    end
  end
end

class AddTypeToVms < ActiveRecord::Migration
  class Vm < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end

  TEMPLATE_HASH = { true => "Template", false => "Vm" }
  VENDOR_HASH   = {
    "vmware"    => "Vmware",
    "microsoft" => "Microsoft",
    "xen"       => "Xen",
    "kvm"       => "Kvm",
    "qemu"      => "Qemu",
    "parallels" => "Parallel",
    "amazon"    => "Amazon",
    "redhat"    => "Redhat",
    "openstack" => "Openstack",
    "unknown"   => "Unknown"
  }

  def up
    add_column    :vms, :type, :string

    say_with_time("Updating Type in Vms") do
      Vm.update_all("type = " + ActiveRecordQueryParts.concat(
                case_for_update("template", TEMPLATE_HASH),
                case_for_update("vendor", VENDOR_HASH)))
    end
  end

  def down
    remove_column :vms, :type
  end

  # FIXME: This should be moved into ActiveRecordQueryParts
  def case_for_update(source_col_name, vals, else_clause = nil)
    quoted_column_name = connection.quote_column_name(source_col_name)

    ret_val = "CASE "
    vals.each do |source_val, target_val|
      ret_val << "WHEN #{quoted_column_name}=#{connection.quote(source_val)} THEN #{connection.quote(target_val)} "
    end
    ret_val << else_clause if else_clause
    ret_val << " END"
  end
end

require 'yaml'

module SerializedEmsRefObjMixin
  def ems_ref_obj
    ref = read_attribute(:ems_ref_obj)
    return ref.nil? ? nil : YAML.load(ref)
  end

  def ems_ref_obj=(ref)
    ref = YAML.dump(ref) unless ref.nil?
    write_attribute(:ems_ref_obj, ref)
  end
end

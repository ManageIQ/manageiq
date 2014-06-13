require 'miq_storage_defs'

class MiqCimAssociation < ActiveRecord::Base
  belongs_to  :result_instance,
        :class_name   => "MiqCimInstance",
        :foreign_key  => "result_instance_id"
  belongs_to  :miq_cim_instance

  STATUS_STALE  = 1
  STATUS_OK   = 0

  include MiqStorageDefs

  def self.add_association(assoc, from_inst, to_inst)
    if (id = get_association_id(assoc, from_inst, to_inst)).nil?
      new_association(assoc, from_inst, to_inst)
    else
      self.where(:id => id).update_all(:status => STATUS_OK, :zone_id => from_inst.zone_id)
    end

    if (id = get_rev_association_id(assoc, from_inst, to_inst)).nil?
      new_rev_association(assoc, from_inst, to_inst)
    else
      self.where(:id => id).update_all(:status => STATUS_OK, :zone_id => from_inst.zone_id)
    end
  end

  def self.new_association(assoc, from_inst, to_inst)
    #
    # Create the forward association.
    #
    new_assoc = self.new
    new_assoc.assoc_class   = assoc[:AssocClass]
    new_assoc.result_class    = to_inst.class_name  # use the specific class instead of the one in assoc
    new_assoc.role        = assoc[:Role]
    new_assoc.result_role   = assoc[:ResultRole]
    new_assoc.obj_name      = from_inst.obj_name_str
    new_assoc.result_obj_name = to_inst.obj_name_str
    new_assoc.result_instance = to_inst
    new_assoc.zone_id     = from_inst.zone_id
    new_assoc.status      = STATUS_OK
    new_assoc.save
    from_inst.miq_cim_associations << new_assoc
    from_inst.save

    return nil
  end

  def self.new_rev_association(assoc, from_inst, to_inst)
    #
    # Create the reverse association.
    #
    new_rassoc = self.new
    new_rassoc.assoc_class    = assoc[:AssocClass]
    new_rassoc.result_class   = from_inst.class_name  # use the specific class instead of the one in assoc
    new_rassoc.role       = assoc[:ResultRole]
    new_rassoc.result_role    = assoc[:Role]
    new_rassoc.obj_name     = to_inst.obj_name_str
    new_rassoc.result_obj_name  = from_inst.obj_name_str
    new_rassoc.result_instance  = from_inst
    new_rassoc.zone_id      = from_inst.zone_id
    new_rassoc.status     = STATUS_OK
    new_rassoc.save
    to_inst.miq_cim_associations << new_rassoc
    to_inst.save

    return nil
  end

  def self.get_association_id(assoc, from_inst, to_inst)
    self.select(:id).find(:first, :conditions => {
      :obj_name     => from_inst.obj_name_str,
      :result_obj_name  => to_inst.obj_name_str,
      :assoc_class    => assoc[:AssocClass],
      # :result_class   => to_inst.class_name,  # use the specific class instead of the one in assoc
      :role       => assoc[:Role],
      # :result_role    => assoc[:ResultRole]
    })
  end

  def self.get_rev_association_id(assoc, from_inst, to_inst)
    self.select(:id).find(:first, :conditions => {
      :obj_name     => to_inst.obj_name_str,
      :result_obj_name  => from_inst.obj_name_str,
      :assoc_class    => assoc[:AssocClass],
      # :result_class   => from_inst.class_name,  # use the specific class instead of the one in assoc
      :role       => assoc[:ResultRole],
      # :result_role    => assoc[:Role]
    })
  end

  def self.where_association(assoc)
    q = where(
      :assoc_class  => assoc[:AssocClass],
      :role     => assoc[:Role],
      :result_role  => assoc[:ResultRole]
    )
    q = q.where(:result_class => cim_classes_based_on(assoc[:ResultClass])) if assoc[:ResultClass]
    return q
  end

  def self.cleanup_by_zone(zoneId)
    total = 0
    aq = self.select(:id).where(:zone_id => zoneId, :status => STATUS_STALE)
    aq.find_in_batches(:batch_size => 100) do |aa|
      ids = aa.collect { |a| a.id }
      total += self.delete_all(:id => ids)
    end
    $log.info "MiqCimAssociation.cleanup_by_zone: deleted #{total} stale associations for zone id #{zoneId}"
  end
end

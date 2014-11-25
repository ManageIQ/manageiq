module EmsRefresh::MetadataRelats
  #
  # EMS Metadata methods for VMDB
  #
  # TODO: Replace with more efficient lookup methods using new relationships

  def vmdb_relats(target, relats = nil)
    log_header = "MIQ(#{self.name}.vmdb_relats)"
    $log.info "#{log_header} Getting VMDB relationships for #{target.class} [#{target.name}] id: [#{target.id}]..."

    relats ||= self.default_relats_hash
    if target.kind_of?(ExtManagementSystem)
      self.vmdb_relats_ems(target, relats)
    else
      self.vmdb_relats_ancestors(target, relats)
      self.vmdb_relats_descendants(target, relats)
    end

    $log.info "#{log_header} Getting VMDB relationships for #{target.class} [#{target.name}] id: [#{target.id}]...Complete"
    return relats
  end

  def vmdb_relats_ems(ems, relats = nil)
    # Use a more optimized vmdb search than following the ancestors and descendants
    relats ||= self.default_relats_hash
    ems.with_relationship_type('ems_metadata') do
      metadata_type_to_meth = Hash.new { |h, k| k }.merge(:folders => :ems_folders, :clusters => :ems_clusters)

      METADATA_TYPES.each do |p_type|
        p_meth = metadata_type_to_meth[p_type]
        next unless ems.respond_to?(p_meth)

        ems.send(p_meth).each do |x|
          x.with_relationship_type('ems_metadata') do
            METADATA_TYPES.each do |c_type|
              # Skip since these are AR relationships
              next if p_type == :clusters && c_type == :hosts
              next if p_type == :clusters && c_type == :vms
              next if p_type == :hosts    && c_type == :vms

              # Handle default resource pools being called differently
              c_meth = ([:hosts, :clusters].include?(p_type) && c_type == :resource_pools) ? :resource_pools_with_default : c_type
              next unless x.respond_to?(c_meth)

              ids = x.send(c_meth).collect {|x2| x2.id}.uniq
              relats["#{p_type}_to_#{c_type}".to_sym][x.id] |= ids unless ids.empty?
            end
          end
        end
      end

      root = ems.ems_folder_root
      relats[:ext_management_systems_to_folders][ems.id] << root.id unless root.nil?
    end
    return relats
  end

  def vmdb_relats_ancestors(target, relats = nil)
    relats ||= self.default_relats_hash

    parents = target.with_relationship_type('ems_metadata') { target.parents.dup }

    # Special cases to also walk the Vm => Host and Host => EmsCluster,
    #   since they are AR relationships
    if target.kind_of?(Vm) && target.host
      parents << target.host
    elsif target.kind_of?(Host) && target.ems_cluster
      parents << target.ems_cluster
    end

    parents.each do |parent|
      relat_type = "#{self.class_to_metadata_type(parent)}_to_#{self.class_to_metadata_type(target)}".to_sym
      relat = relats.fetch_path(relat_type, parent.id)
      relat << target.id unless relat.include?(target.id)

      self.vmdb_relats_ancestors(parent, relats)
    end

    # Remove the direct Host => Vms and EmsCluster => Host special cases if found
    relats.delete(:hosts_to_vms)
    relats.delete(:clusters_to_hosts)

    return relats
  end

  def vmdb_relats_descendants(target, relats = nil)
    relats ||= self.default_relats_hash

    children = target.with_relationship_type('ems_metadata') { target.children }

    children.each do |child|
      relat_type = "#{self.class_to_metadata_type(target)}_to_#{self.class_to_metadata_type(child)}".to_sym
      relat = relats.fetch_path(relat_type, target.id)
      relat << child.id unless relat.include?(child.id)

      self.vmdb_relats_descendants(child, relats)
    end

    return relats
  end

  #
  # EMS Metadata methods for hashes
  #

  def hashes_relats(hashes, relats = nil)
    relats ||= self.default_relats_hash

    METADATA_TYPES.each do |p_type|
      parents = hashes[p_type]
      next if parents.blank?

      parents.each do |parent|
        p_id = parent[:id]
        all_children = parent[:ems_children]
        next if p_id.blank? || all_children.blank?

        all_children.each do |c_type, children|
          # Skip since these are AR relationships
          next if p_type == :clusters && c_type == :hosts
          next if p_type == :clusters && c_type == :vms
          next if p_type == :hosts    && c_type == :vms

          ids = children.collect { |c| c[:id] }.compact.uniq
          relats["#{p_type}_to_#{c_type}".to_sym][p_id] |= ids unless ids.empty?
        end
      end
    end

    root = hashes.fetch_path(:ems_root, :id)
    relats[:ext_management_systems_to_folders][hashes[:id]] << root unless root.blank?

    return relats
  end

  #
  # Helper methods for EMS metadata processing
  #

  METADATA_TYPES = [:folders, :clusters, :resource_pools, :hosts, :vms]

  def class_to_metadata_type(klass)
    klass = klass.constantize if klass.kind_of?(String)
    klass = klass.class unless klass.kind_of?(Class)
    klass = klass.base_class
    type  = klass.to_s.underscore.pluralize
    type  = "vms" if type == "vms_and_templates"
    type  = type[4..-1] if type[0..3] == "ems_"
    return type.to_sym
  end

  def default_relats_hash
    Hash.new { |h, k| h[k] = Hash.new { |h2, k2| h2[k2] = Array.new } }
  end
end

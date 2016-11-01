module ManagerRefresh
  class DtoCollection
    attr_accessor :saved, :data, :data_index, :dependency_attributes,
                  :manager_ref, :attributes, :association, :parent

    attr_reader :model_class, :strategy, :attributes_blacklist, :attributes_whitelist, :custom_save_block,
                :internal_attributes

    def initialize(model_class, manager_ref: nil, attributes: nil, association: nil, parent: nil, strategy: nil,
                   custom_save_block: nil)
      @model_class           = model_class
      @manager_ref           = manager_ref || [:ems_ref]
      @attributes            = attributes || []
      @association           = association || []
      @parent                = parent || []
      @dependency_attributes = {}
      @data                  = []
      @data_index            = {}
      @saved                 = false
      @strategy              = process_strategy(strategy)
      @attributes_blacklist  = Set.new
      @attributes_whitelist  = Set.new
      @custom_save_block     = custom_save_block
      @internal_attributes   = [:__feedback_edge_set_parent]
    end

    def process_strategy(strategy_name)
      if strategy_name == :local_db_cache_all
        process_strategy_local_db_cache_all
      end
      strategy_name
    end

    def process_strategy_local_db_cache_all
      self.saved = true
      selected   = [:id] + manager_ref
      selected << :type if model_class.new.respond_to? :type
      parent.send(association).select(selected).find_each do |record|
        self.data_index[object_index(record)] = record
      end
    end

    def saved?
      saved
    end

    def saveable?
      dependencies.all?(&:saved?)
    end

    def <<(dto)
      unless data_index[dto.manager_uuid]
        data_index[dto.manager_uuid] = dto
        data << dto

        actualize_dependencies(dto)
      end
    end

    def object_index(object)
      manager_ref.map { |attribute| object.public_send(attribute).try(:id) || object.public_send(attribute).to_s }.join("__")
    end

    def find(manager_uuid)
      data_index[manager_uuid]
    end

    def lazy_find(manager_uuid, path: nil, default: nil)
      ::ManagerRefresh::DtoLazy.new(self, manager_uuid, :path => path, :default => default)
    end

    def new_dto(hash)
      ::ManagerRefresh::Dto.new(self, hash)
    end

    def each(*args, &block)
      data.each(*args, &block)
    end

    def to_a
      data
    end

    def size
      to_a.size
    end

    def to_hash
      data_index
    end

    def fixed_dependencies
      presence_validators = model_class.validators.detect { |x| x.kind_of? ActiveRecord::Validations::PresenceValidator }
      # Attributes that has to be always on the entity, so attributes making unique index of the record + attributes
      # that have presence validation
      fixed_attributes    = manager_ref
      fixed_attributes    += presence_validators.attributes unless presence_validators.blank?

      fixed_dependencies = Set.new
      dependency_attributes.each do |key, value|
        fixed_dependencies += value if fixed_attributes.include?(key)
      end
      fixed_dependencies
    end

    def dependencies
      dependency_attributes.values.map(&:to_a).flatten.uniq
    end

    def dependency_attributes_for(dto_collections)
      attributes = Set.new
      dto_collections.each do |dto_collection|
        attributes += dependency_attributes.select { |_key, value| value.include?(dto_collection) }.keys
      end
      attributes
    end

    def blacklist_attributes!(attributes)
      # The manager_ref attributes cannot be blacklisted, otherwise we will not be able to identify the dto object. We
      # do not automatically remove attributes causing fixed dependencies, so beware that without them, you won't be
      # able to create the record.
      self.attributes_blacklist += attributes - (manager_ref + internal_attributes)
      dependency_attributes.delete_if { |key, _value| attributes_blacklist.include?(key) }
    end

    def whitelist_attributes!(attributes)
      # The manager_ref attributes always needs to be in the white list, otherwise we will not be able to identify the
      # dto object. We do not automatically add attributes causing fixed dependencies, so beware that without them, you
      # won't be able to create the record.
      self.attributes_whitelist += attributes + (manager_ref + internal_attributes)
      dependency_attributes.delete_if { |key, _value| !attributes_whitelist.include?(key) }
    end

    def clone
      # A shallow copy of DtoCollection, the copy will share @data of the original collection, otherwise we would be
      # copying a lot of records in memory.
      new_dto_collection = self.class.new(self.model_class,
                                          manager_ref:       self.manager_ref,
                                          association:       self.association,
                                          parent:            self.parent,
                                          strategy:          self.strategy,
                                          custom_save_block: self.custom_save_block)

      new_dto_collection.data                  = self.data
      new_dto_collection.data_index            = self.data_index
      # Dependency attributes need to be a hard copy, since those will differ for each DtoCollection
      new_dto_collection.dependency_attributes = self.dependency_attributes.clone
      new_dto_collection
    end

    def to_s
      whitelist = ", whitelist: [#{attributes_whitelist.to_a.join(", ")}]" unless attributes_whitelist.blank?
      blacklist = ", blacklist: [#{attributes_blacklist.to_a.join(", ")}]" unless attributes_blacklist.blank?

      "DtoCollection:<#{@model_class}>#{whitelist}#{blacklist}"
    end

    def inspect
      to_s
    end

    private

    attr_writer :attributes_blacklist, :attributes_whitelist

    def actualize_dependencies(dto)
      dto.data.each do |key, value|
        if is_dependency?(value)
          (dependency_attributes[key] ||= Set.new) << value.dto_collection
        elsif value.kind_of?(Array) && value.any? { |x| is_dependency?(x) }
          (dependency_attributes[key] ||= Set.new) << value.detect { |x| is_dependency?(x) }.dto_collection
        end
      end
    end

    def is_dependency?(value)
      (value.kind_of?(::ManagerRefresh::DtoLazy) && value.dependency?) || value.kind_of?(::ManagerRefresh::Dto)
    end
  end
end

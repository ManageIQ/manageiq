class Condition < ApplicationRecord
  include UuidMixin
  include ReadOnlyMixin

  before_validation :default_name_to_guid, :on => :create

  validates :name, :description, :expression, :towhat, :presence => true
  validates :name, :description, :uniqueness_when_changed => true

  acts_as_miq_taggable
  acts_as_miq_set_member

  belongs_to :miq_policy
  has_and_belongs_to_many :miq_policies

  serialize :expression
  serialize :applies_to_exp

  attr_accessor :reserved

  TOWHAT_APPLIES_TO_CLASSES = {
    "ContainerGroup"      => ui_lookup(:model => "ContainerGroup"),
    "ContainerImage"      => ui_lookup(:model => "ContainerImage"),
    "ContainerNode"       => ui_lookup(:model => "ContainerNode"),
    "ContainerProject"    => ui_lookup(:model => "ContainerProject"),
    "ContainerReplicator" => ui_lookup(:model => "ContainerReplicator"),
    "ExtManagementSystem" => ui_lookup(:model => "ExtManagementSystem"),
    "Host"                => ui_lookup(:model => "Host"),
    "PhysicalServer"      => ui_lookup(:model => "PhysicalServer"),
    "Vm"                  => ui_lookup(:model => "Vm")
  }.freeze

  def applies_to?(rec, inputs = {})
    rec_model = rec.class.base_model.name
    rec_model = "Vm" if rec_model.downcase.match?("template")

    return false if towhat && rec_model != towhat
    return true  if applies_to_exp.nil?

    Condition.evaluate(self, rec, inputs, :applies_to_exp)
  end

  def self.conditions
    pluck(:expression)
  end

  def self.evaluate(cond, rec, _inputs = {}, attr = :expression)
    expression = cond.send(attr)
    name = cond.try(:description) || cond.try(:name)
    mode = expression.kind_of?(MiqExpression) ? "object" : expression["mode"]

    case mode
    when "tag"
      unless %w[any all none].include?(expression["include"])
        raise _("condition '%{name}', include value \"%{value}\", is invalid. Should be one of \"any, all or none\"") %
                {:name => name, :value => expression["include"]}
      end

      result = expression["include"] != "any"
      expression["tag"].split.each do |tag|
        if rec.is_tagged_with?(tag, :ns => expression["ns"])
          result = true if expression["include"] == "any"
          result = false if expression["include"] == "none"
        else
          result = false if expression["include"] == "all"
        end
      end
    when "tag_expr", "tag_expr_v2", "object"
      expr = case mode
             when "tag_expr"
               expression["expr"]
             when "tag_expr_v2"
               MiqExpression.new(expression["expr"]).to_ruby
             when "object"
               expression.to_ruby
             end
      result = subst_matches?(expr, rec)
    end
    result
  end

  # similar to MiqExpression#evaluate
  # @return [Boolean] true if the expression matches the record
  def self.subst_matches?(expr, rec)
    do_eval(subst(expr, rec))
  end

  def self.do_eval(expr)
    !!eval(expr)
  end
  private_class_method :do_eval

  def self.subst(expr, rec)
    findexp = /<find>(.+?)<\/find>/im
    if expr =~ findexp
      expr = expr.gsub!(findexp) { |_s| _subst_find(rec, $1.strip) }
      MiqPolicy.logger.debug("MIQ(condition-_subst_find): Find Expression after substitution: [#{expr}]")
    end

    # <mode>/virtual/operating_system/product_name</mode>
    # <mode WE/JWSref=host>/managed/environment/prod</mode>
    expr.gsub!(/<(value|exist|count|registry)([^>]*)>([^<]+)<\/(value|exist|count|registry)>/im) { |_s| _subst(rec, $2.strip, $3.strip, $1.strip) }

    # <mode /virtual/operating_system/product_name />
    expr.gsub!(/<(value|exist|count|registry)([^>]+)\/>/im) { |_s| _subst(rec, nil, $2.strip, $1.strip) }

    expr
  end
  private_class_method :subst

  def self._subst(rec, opts, tag, mode)
    ohash, ref = options2hash(opts, rec)

    case mode.downcase
    when "exist"
      ref.nil? ? value = false : value = ref.is_tagged_with?(tag, :ns => "*")
    when "value"
      if ref.kind_of?(Hash)
        value = ref.fetch(tag, "")
      else
        value = ref.nil? ? "" : Tag.list(ref, :ns => tag)
      end
      value = MiqExpression.quote(value, ohash[:type]&.to_sym)
    when "count"
      ref.nil? ? value = 0 : value = ref.tag_list(:ns => tag).length
    when "registry"
      ref.nil? ? value = "" : value = registry_data(ref, tag, ohash)
      value = MiqExpression.quote(value, ohash[:type]&.to_sym)
    end
    value
  end
  private_class_method :_subst

  def self.collect_children(ref, methods)
    method = methods.shift

    list = ref.send(method)
    return [] if list.nil?

    result = methods.empty? ? Array(list) : []
    Array(list).each do |obj|
      result.concat(collect_children(obj, methods)) unless methods.empty?
    end
    result
  end
  private_class_method :collect_children

  def self._subst_find(rec, expr)
    MiqPolicy.logger.debug("MIQ(condition-_subst_find): Find Expression before substitution: [#{expr}]")
    searchexp = /<search>(.+)<\/search>/im
    expr =~ searchexp
    search = $1
    MiqPolicy.logger.debug("MIQ(condition-_subst_find): Search Expression before substitution: [#{search}]")

    listexp = /<value([^>]*)>(.+)<\/value>/im
    search =~ listexp
    opts, _ref = options2hash($1, rec)
    methods = $2.split("/")
    methods.shift
    methods.shift
    attr = methods.pop
    l = collect_children(rec, methods)

    return false if l.empty?

    list = l.collect do |obj|
      value = MiqExpression.quote(obj.send(attr), opts[:type]&.to_sym)
      value = value.gsub("\\", '\&\&') if value.kind_of?(String)
      e = search.gsub(/<value[^>]*>.+<\/value>/im, value.to_s)
      obj if do_eval(e)
    end.compact

    MiqPolicy.logger.debug("MIQ(condition-_subst_find): Search Expression returned: [#{list.length}] records")

    checkexp = /<check([^>]*)>(.+)<\/check>/im

    expr =~ checkexp
    checkopts = $1.strip
    check = $2
    checkmode = checkopts.split("=").last.strip.downcase

    MiqPolicy.logger.debug("MIQ(condition-_subst_find): Check Expression before substitution: [#{check}], options: [#{checkopts}]")

    if checkmode == "count"
      e = check.gsub(/<count>/i, list.length.to_s)
      left, operator, right = e.split
      raise _("Illegal operator, '%{operator}'") % {:operator => operator} unless %w[== != < > <= >=].include?(operator)

      MiqPolicy.logger.debug("MIQ(condition-_subst_find): Check Expression after substitution: [#{e}]")
      result = !!left.to_f.send(operator, right.to_f)
      MiqPolicy.logger.debug("MIQ(condition-_subst_find): Check Expression result: [#{result}]")
      return result
    end

    return false if list.empty?

    check =~ /<value([^>]*)>(.+)<\/value>/im
    raw_opts = $1
    tag = $2
    checkattr = tag.split("/").last.strip

    result = true
    list.each do |obj|
      opts, _ref = options2hash(raw_opts, obj)
      value = MiqExpression.quote(obj.send(checkattr), opts[:type]&.to_sym)
      value = value.gsub("\\", '\&\&') if value.kind_of?(String)
      e = check.gsub(/<value[^>]*>.+<\/value>/im, value.to_s)
      MiqPolicy.logger.debug("MIQ(condition-_subst_find): Check Expression after substitution: [#{e}]")

      result = do_eval(e)

      return true if result && checkmode == "any"
      return false if !result && checkmode == "all"
    end
    MiqPolicy.logger.debug("MIQ(condition-_subst_find): Check Expression result: [#{result}]")
    result
  end

  def self.options2hash(opts, rec)
    ref = rec
    ohash = {}
    if opts.present?
      val = nil
      opts.split(",").each do |o|
        attr, val = o.split("=")
        ohash[attr.strip.downcase.to_sym] = val.strip.downcase
      end
      if ohash[:ref] != rec.class.to_s.downcase && !exclude_from_object_ref_substitution(ohash[:ref], rec)
        ref = rec.send(val) if val && rec.respond_to?(val)
      end
    end
    return ohash, ref
  end

  def self.exclude_from_object_ref_substitution(reference, rec)
    case reference
    when "service"
      rec.kind_of?(Service)
    end
  end

  def self.registry_data(ref, name, ohash)
    # <registry>HKLM\Software\Microsoft\Windows\CurrentVersion\explorer\Shell Folders\Common AppData</registry> == 'C:\Documents and Settings\All Users\Application Data'
    # <registry>HKLM\Software\Microsoft\Windows\CurrentVersion\explorer\Shell Folders : Common AppData</registry> == 'C:\Documents and Settings\All Users\Application Data'
    return nil unless ref.respond_to?(:registry_items)

    registry_items = ref.registry_items
    if ohash[:key_exists]
      registry_items.where("name LIKE ? ESCAPE ''", name + "%").exists?
    elsif ohash[:value_exists]
      registry_items.where(:name => name).exists?
    else
      registry_items.find_by(:name => name)&.data
    end
  end

  def export_to_array
    h = attributes
    ["id", "created_on", "updated_on"].each { |k| h.delete(k) }
    [self.class.to_s => h]
  end

  def self.import_from_hash(condition, options = {})
    # To delete condition modifier in policy from versions 5.8 and older
    condition["expression"].exp = {"not" => condition["expression"].exp} if condition["modifier"] == 'deny'
    condition.delete("modifier")

    status = {:class => name, :description => condition["description"]}
    c = Condition.find_by(:guid => condition["guid"]) || Condition.find_by(:name => condition["name"]) ||
        Condition.find_by(:description => condition["description"])
    msg_pfx = "Importing Condition: guid=[#{condition["guid"]}] description=[#{condition["description"]}]"

    if c.nil?
      c = Condition.new(condition)
      status[:status] = :add
    else
      status[:old_description] = c.description
      c.attributes = condition
      status[:status] = :update
    end

    unless c.valid?
      status[:status]   = :conflict
      status[:messages] = c.errors.full_messages
    end

    msg = "#{msg_pfx}, Status: #{status[:status]}"
    msg += ", Messages: #{status[:messages].join(",")}" if status[:messages]
    if options[:preview] == true
      MiqPolicy.logger.info("[PREVIEW] #{msg}")
    else
      MiqPolicy.logger.info(msg)
      c.save!
    end

    return c, status
  end
end # class Condition

require 'miq_storage_defs'

class CimAssoc
  def initialize(&block)
    @from_class   = nil
    @result_class = nil
    @assoc_class  = nil
    @role     = nil
    @result_role  = nil
    block.arity < 1 ? instance_eval(&block) : block.call(self) unless block.nil?
  end

  def reverse!
    @from_class, @result_class = @result_class, @from_class
    @role, @result_role = @result_role, @role
    self
  end

  def reverse
    dup.reverse!
  end

  def dump(offset = "", lvl = 0)
    ip("<#{self.class.name}>",          lvl, offset)
    ip("    assoc_class:  #{@assoc_class}",   lvl, offset)
    ip("    from_class:   #{@from_class}",    lvl, offset)
    ip("    result_class: #{@result_class}",  lvl, offset)
    ip("    role:         #{@role}",      lvl, offset)
    ip("    result_role:  #{@result_role}",   lvl, offset)
    ip("<END: #{self.class.name}>",       lvl, offset)
  end

  def ip(s, i, o)
    print o + "    " + "        " * i
    puts s
  end
  private :ip

  def [](sym)
    send(sym.to_s.underscore.to_sym)
  end

  def []=(sym, val)
    send((sym.to_s.underscore + "=").to_sym, val)
  end

  def method_missing(sym, *args)
    key = sym.to_s.insert(0, '@')
    if key[-1, 1] == '='
      key = key[0...-1]
      return instance_variable_set(key, args[0])
    elsif args.length == 1
      return instance_variable_set(key, args[0])
    else
      return instance_variable_get(key)
    end
  end
end # class CimAssoc

class CimProfNode
  attr_reader :flags, :association, :next
  attr_writer :tag

  TAG_DELIMITER = "_to_"

  def initialize(&block)
    @tag      = nil
    @flags      = {}
    @association  = []  # Array of CimAssoc
    @next     = CimProfNodeGroup.new  # Array of CimProfNode (children)
    block.arity < 1 ? instance_eval(&block) : block.call(self) unless block.nil?
  end

  def tag(val = nil)
    return @tag if val.nil?
    @tag = val
  end

  def add_association(assoc)
    if assoc.kind_of?(Symbol)
      a = CimAssociations[assoc]
      raise "#{self.class.name}.add_association: association #{assoc} not found" if a.nil?
      assoc = a
    end
    @association << assoc
  end

  #
  # Add the CimProfNode to the children if the current node.
  #
  def add_next!(node = nil, &block)
    node = get_node(node)
    block.arity < 1 ? node.instance_eval(&block) : block.call(node) unless block.nil?
    @next.add(node)
    self
  end

  def add_next(node = nil, &block)
    new_me = deep_dup
    new_me.add_next!(node, &block)
    new_me
  end

  def +(node = nil)
    add_next(node)
  end

  #
  # Append the CimProfNode to the end of the next chain of the current branch.
  #
  def append_next!(node = nil, &block)
    if @next.empty?
      node = get_node(node)
      block.arity < 1 ? node.instance_eval(&block) : block.call(node) unless block.nil?
      @next.add(node)
      return self
    end
    raise "#{self.class.name}.append_next: cannot append to branch with fork" if @next.length > 1
    @next.first.append_next!(node, &block)
    self
  end

  def append_next(node = nil, &block)
    new_me = deep_dup
    new_me.append_next!(node, &block)
    new_me
  end

  def <<(node = nil)
    append_next(node)
  end

  def add_flags(flags)
    @flags.merge!(flags)
  end

  def remove_flags(*args)
    args.each { |f| @flags.delete(f) }
  end

  def clear_flags
    @flags.clear
  end

  def reverse!
    raise "#{self.class.name}.reverse!: can't reverse multi-association profile, tag = #{@tag}" unless @association.length == 1
    @association[0] = CimAssociations.add_reverse(@association[0])
    @tag = reverse_tag(@tag)
    self
  end

  def reverse
    dup.reverse!
  end

  def update(&block)
    block.arity < 1 ? instance_eval(&block) : block.call(self)
  end

  def dup
    d = self.class.new
    d.tag = @tag
    d.add_flags(@flags)
    @association.each { |a| d.add_association(a) }
    d
  end

  def deep_dup
    d = dup
    d.next.add(@next.deep_dup)
    d
  end

  def node_with_tag(tag)
    return self if @tag == tag
    @next.node_with_tag(tag)
  end

  #
  # attr_readers accessed as hash
  #
  def [](tag)
    send(tag)
  end

  def check(offset = "", lvl = 0, rank = 0)
    puts offset + "#{self.class.name}.check: level = #{lvl}, rank = #{rank} START"
    association.each { |fa| self.next.check_next(offset, fa, lvl, rank) }
    puts offset + "#{self.class.name}.check: level = #{lvl}, rank = #{rank} END"
    puts

    self.next.each_with_index { |n, i| n.check(offset, lvl + 1, i) }
    nil
  end

  def dump(offset = "", lvl = 0, rank = 0)
    ip("<#{self.class.name}> (#{object_id}) [#{lvl}, #{rank}]", lvl, offset)
    ip("    tag:   #{@tag}", lvl, offset)
    ip("    flags: #{@flags.inspect}", lvl, offset)
    ip("    associations:", lvl, offset)
    @association.each { |a| a.dump(offset, lvl) }
    ip("    next:", lvl, offset)
    @next.dump(offset, lvl)
    ip("<END: #{self.class.name}> (#{object_id}) [#{lvl}, #{rank}]", lvl, offset)
  end

  def method_missing(sym, *args)
    super if (rv = CimProfiles[sym]).nil?
    rv
  end

  def reverse_tag(tag)
    tag = tag.to_s
    sa = tag.split(TAG_DELIMITER)
    return (tag + "_reversed").to_sym unless sa.length == 2
    (sa[1] + TAG_DELIMITER + sa[0]).to_sym
  end
  private :reverse_tag

  def get_node(node)
    if node.nil?
      node = self.class.new
    elsif node.kind_of?(Symbol)
      n = CimProfiles[node]
      raise "#{self.class.name}: profile #{node} not found" if n.nil?
      node = n.deep_dup
    else
      node = node.deep_dup
    end
    node
  end
  private :get_node

  def ip(s, i, o)
    print o + "    " + "        " * (i - 1) if i >= 1
    puts s
  end
  private :ip
end # class CimProfNode

class CimProfNodeGroup < Array
  include MiqStorageDefs

  def initialize(&block)
    super()
    @input_class = nil

    unless block.nil?
      block.arity < 1 ? instance_eval(&block) : block.call(self)
    end
  end

  def input_class(cim_class = nil)
    return @input_class if cim_class.nil?
    @input_class = cim_class
  end

  def node(&block)
    node = CimProfNode.new
    unless block.nil?
      block.arity < 1 ? node.instance_eval(&block) : block.call(node)
    end
    push(node)
  end

  def add(node)
    if node.kind_of?(Symbol)
      n = CimProfiles[node]
      raise "#{self.class.name}.add: profile #{node} not found" if n.nil?
      node = n
    end
    node = node.deep_dup

    if node.kind_of?(CimProfNode)
      push(node)
    elsif node.kind_of?(CimProfNodeGroup)
      concat(node)
    end
  end

  #
  # This replaces Array::<< so care must be taken to use "push" instead of "<<"
  # when the Array behavior is desired.
  #
  def <<(node)
    raise "#{self.class.name}.append_next: cannot append to branch with fork" if length > 1
    if self.empty?
      push(node)
    else
      first.append_next(node)
    end
  end

  def prepend(node)
    node.add_next!(self)
    clear
    self[0] = node
  end

  def node_with_tag(tag)
    each do |n|
      unless (rv = n.node_with_tag(tag)).nil?
        return rv
      end
    end
    nil
  end

  def reverse(head = nil)
    raise "#{self.class.name}.reverse: can't reverse branched profile" unless length <= 1

    head = self.class.new if head.nil?
    return head if self.empty?

    node = first
    rnode = node.reverse
    head.prepend(rnode)
    head.input_class(rnode.association.first.from_class)
    node.next.reverse(head)
  end

  def deep_dup
    ng = self.class.new
    each { |n| ng.add(n.deep_dup) }
    ng
  end

  def check(offset = "", lvl = 0, rank = 0)
    puts offset + "#{self.class.name}.check: level = #{lvl}, rank = #{rank} START"
    check_next(offset, nil, lvl, rank)
    puts offset + "#{self.class.name}.check: level = #{lvl}, rank = #{rank} END"
    puts
    each_with_index { |n, i| n.check(offset, lvl + 1, i) }
  end

  def cim_class_hier(cim_class)
    return [cim_class] if (ch = CIM_CLASS_HIER[cim_class]).nil?
    ch
  end
  private :cim_class_hier

  def check_next(offset = "", from_assoc = nil, _lvl = 0, _rank = 0)
    if from_assoc
      input_class = from_assoc.result_class
      assoc_class = from_assoc.assoc_class
    else
      raise "#{self.class.name}.check_next: input_class is not set" if (input_class = @input_class).nil?
      assoc_class = 'TOP'
    end

    each do |n|
      n.association.each do |ta|
        next_class = ta.from_class
        unless cim_class_hier(input_class).include?(next_class) ||
               cim_class_hier(next_class).include?(input_class)
          puts offset + "  tag: #{n.tag}" unless n.tag.nil?
          puts offset + "    #{assoc_class}: input_class #{input_class}, doesn't match #{next_class}"
        end
      end
    end
  end

  def dump(offset = "", lvl = 0)
    puts offset + "input_class: #{@input_class}" unless @input_class.nil?
    each_with_index { |n, i| n.dump(offset, lvl + 1, i) }
  end

  def method_missing(sym, *args)
    super if (rv = CimProfiles[sym]).nil?
    rv
  end
end # class CimProfNodeGroup

class CimAssociations < Hash
  private_class_method :new, :[]

  DELIMITER = '_TO_'

  def self.update(name_sfx = "", &block)
    @instance = new unless @instance

    #
    # Update should be serialized through the load process,
    # so using a class variable should be ok.
    #
    @@name_sfx = name_sfx
    unless block.nil?
      block.arity < 1 ? @instance.instance_eval(&block) : block.call(@instance)
      @instance.default = nil
    end
    @@name_sfx = ""
  end

  def initialize
    super()
  end

  def add(assoc = nil, &block)
    raise "#{self.class.name}.add: association or block required" if assoc.nil? && block.nil?

    if assoc.nil?
      assoc = CimAssoc.new(&block)
    else
      unless block.nil?
        asscoc = assoc.dup
        block.arity < 1 ? assoc.instance_eval(&block) : block.call(assoc)
        self.default = nil
      end
    end

    fa_tag = assoc_tag(assoc)
    raise "#{self.class.name}.add: association already exist #{fa_tag}" if self.key?(fa_tag)
    self[fa_tag] = assoc
    add_reverse(assoc)

    nil
  end

  def add_reverse(assoc)
    rassoc = assoc.reverse
    ra_tag = assoc_tag(rassoc)
    self[ra_tag] = rassoc unless self.key?(ra_tag)
    rassoc
  end

  def self.add_reverse(assoc)
    @instance.add_reverse(assoc)
  end

  def remove(sym)
    delete(sym)
  end

  def method_missing(sym, *args, &block)
    if args.empty? && block.nil?
      raise "#{self.class.name}: association named #{sym} not found" unless self.key?(sym)
      return self[sym]
    end

    raise "#{self.class.name}: association named #{sym} already exists" if self.key?(sym)

    if args.empty?
      assoc = CimAssoc.new
    else
      raise "#{self.class.name}.#{sym}: wrong number of arguments #{args.length} for 1" unless args.length == 1
      if (assoc = args.first).kind_of?(Symbol)
        a = self[assoc]
        raise "#{self.class.name}.#{sym}: association #{assoc} not found" if a.nil?
        assoc = a
      end
    end
    raise "#{self.class.name}.#{sym}: arg is not a CimAssoc (#{assoc.class.name})" unless assoc.kind_of?(CimAssoc)
    block.arity < 1 ? assoc.instance_eval(&block) : block.call(assoc) unless block.nil?
    self[sym] = assoc
  end

  def self.list
    @instance.keys.sort { |a, b| a.to_s <=> b.to_s }.each { |k| puts k }
  end

  def self.method_missing(sym, *args, &block)
    @instance.send(sym, *args, &block)
  end

  def assoc_tag(assoc)
    (assoc.from_class.to_s + DELIMITER + assoc.result_class.to_s + @@name_sfx).to_sym
  end
  private :assoc_tag
end # class CimAssociations

class CimProfiles < Hash
  private_class_method :new, :[]

  def self.update(&block)
    @instance = new unless @instance

    unless block.nil?
      block.arity < 1 ? @instance.instance_eval(&block) : block.call(@instance)
      @instance.default = nil
    end
  end

  def initialize
    super()
  end

  #
  # Given its name, look up the profile in the hash.
  # Like [], but it dups the profile and passes it to the block, if given.
  #
  def lookup(sym, &block)
    raise "#{self.class.name}.lookup: profile #{sym} not found." if (node = self[sym]).nil?
    node = node.deep_dup
    block.arity < 1 ? node.instance_eval(&block) : block.call(node) unless block.nil?
    node
  end

  def method_missing(sym, *args, &block)
    if args.empty? && block.nil?
      raise "#{self.class.name}: profile named #{sym} not found" unless self.key?(sym)
      return self[sym]
    end

    raise "#{self.class.name}.#{sym}: profile already exists" if self.key?(sym)

    if args.empty?
      node = CimProfNodeGroup.new
    else
      raise "#{self.class.name}.#{sym}: wrong number of arguments #{args.length} for 1" unless args.length == 1
      if (node = args.first).kind_of?(Symbol)
        n = self[node]
        raise "#{self.class.name}.#{sym}: profile #{node} not found" if n.nil?
        node = n
      elsif node.kind_of?(CimAssoc)
        node = CimProfNode.new do
          tag sym
          add_association node
        end
      end
    end
    if node.kind_of?(CimProfNode)
      node = CimProfNodeGroup.new do
        input_class node.association.first.from_class
        add node
      end
    end

    raise "#{self.class.name}.#{sym}: arg is not a CimProfNodeGroup (#{node.class.name})" unless node.kind_of?(CimProfNodeGroup)
    block.arity < 1 ? node.instance_eval(&block) : block.call(node) unless block.nil?
    self[sym] = node
  end

  def self.method_missing(sym, *args, &block)
    @instance.send(sym, *args, &block)
  end

  # Constants are looked up in global scope in instance_eval,
  # so this doesn't work.
  def self.const_missing(sym)
    @instance.send(sym, [], nil)
  end

  def self.list
    @instance.keys.sort { |a, b| a.to_s <=> b.to_s }.each { |k| puts k }
  end

  def self.check
    puts "#{name}.check: Checking profiles..."
    keys = @instance.keys.sort { |a, b| a.to_s <=> b.to_s }
    keys.each do |pn|
      puts "    #{pn}:"
      @instance[pn].check('        ')
    end
    puts "#{name}.check: Done."
  end
end # class CimProfiles

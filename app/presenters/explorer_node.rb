class ExplorerNode
  attr_accessor :original_value, :elements

  ##########################################################
  # Examples of x_node string that need to be parsed
  #
  # we add xx prefix to all folder nodes to detect if
  # a user is on a folder node or a subfolder node
  #
  ##########################################################
  #
  # -Unassigned
  #    which denotes that nothing is assigned
  #
  # xx-Compute_cr-1r5
  #    which denotes that user is viewing a chargeback rate with
  #    id 1000000000005 that's under Compute folder in the tree
  #
  # xx-1_xx-1-0_rep-1r1
  #    which denotes that report node that user is on is a report
  #    buried under 2 levels of folders, currently OOTB reports
  #    are stored under folders & subfolders and we get array of
  #    arrays back from back end so in order to keep track of active
  #    node we separate each folder id with _ and use array element
  #    position in id
  #
  # xx-1r340
  #    in saved reports accordion when viewing saved reports under
  #    a report folder id with list view on the right
  #
  # xx-1r340_rr-1r582
  #    when viewing an actual saved report that contains the actual
  #    report to display on the right
  #
  # xx-1_xx-1-0_rep-1r1
  #    when viewing a report from Reports tree and user is on Reports
  #    Info tab
  #
  # g-1r31
  #    when editing a MiqGroup record in OPS id
  #
  # xx-g
  #    when adding a new one under Groups folder id
  #
  ##########################################################
  def initialize(value)
    @original_value = value
    @elements = value.split("_").collect do |element|
      prefix, id = element.split("-")
      prefix     = nil if prefix.blank?
      id         = nil if id.blank?
      id         = id.join("-") if id.kind_of?(Array)
      class_name = TreeBuilder.get_model_for_prefix(prefix)

      {:prefix => prefix, :class_name => class_name, :id => id}
    end
  end

  def first
    @elements.first
  end

  def last
    @elements.last
  end

  def root?
    @elements.first[:prefix] == 'root'
  end

  def zone?
    @elements.first[:class_name] == 'Zone'
  end

  def miq_server?
    @elements.first[:class_name] == 'MiqServer'
  end

  def vmdb_index?
    @elements.first[:class_name] == 'VmdbIndex'
  end

  def hash?
    @elements.first[:class_name] == 'Hash'
  end
end

module OpsHelper
  include_concern 'TextualSummary'
  include_concern 'MyServer'

  def hide_button(button, opt)
    if opt == "on"
      button ? '' : 'display:none'
    else
      button ? 'display:none' : ''
    end
  end

  def selected_settings_tree?(tree_node)
    tree_keys = tree_node.split("-")
    # only 'root' key has 1 key after split
    if tree_keys.count == 2
      tree_keys.any? { |t_key| %w(msc sis z l ld lr).include? t_key }
    else
      false
    end
  end

  def selected?(tree_node, key)
    tree_node.split('-').first == key
  end

  def auth_mode_name
    case ::Settings.authentication.mode.downcase
    when 'ldap'
      _('LDAP')
    when 'ldaps'
      _('LDAPS')
    when 'amazon'
      _('Amazon')
    when 'httpd'
      _('External Authentication')
    when 'database'
      _('Database')
    end
  end
end

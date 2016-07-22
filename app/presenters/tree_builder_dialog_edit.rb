class TreeBuilderDialogEdit < TreeBuilder
  has_kids_for Hash, [:x_get_tree_hash_kids]

  def initialize(name, type, sandbox, build = true, root = nil)
    @root = root
    super(name, type, sandbox, build)
  end

  private

  def tree_init_options(_tree_name)
    {:full_ids => true, :lazy => false}
  end

  def set_locals_for_render
    locals = super
    locals.merge!(:id_prefix                   => "de_",
                  :autoload                    => true,
                  :url                         => '/vm/show/',
                  :open_close_all_on_dbl_click => true,
                  :cookie_id_prefix            => "edit_treeOpenStatex",
                  :exp_tree                    =>  true,
                  :onclick                     => "miqOnClickSelectDlgEditTreeNode",)
  end

  def root_options
    ["#{@root[:new][:label] || _('[New Dialog]')}", @root[:new][:description] || @root[:new][:label], "dialog"]
  end

  def x_get_tree_roots(count_only = false, _options)
    nodes = @root[:new][:tabs].map do |node|
      {:id => "root_#{node[:id]}",
       :text => t = node[:label] || _('[New Tab]'),
       :image => "dialog_tab",
       :tip => t,
       :expand => true,
       :children => node[:groups].present? ? node[:groups] : []
      }
    end
    count_only ? nodes.size : nodes
  end

  def x_get_tree_hash_kids(parent, count_only)
    nodes = parent[:children].map do |node|
      if node[:fields].present?
        {:id => "#{parent[:id]}_#{node[:id]}",
         :text => node[:label] || _('[New Box]'),
         :image => "dialog_group",
         :tip => node[:description] || node[:label],
         :expand => true,
         :children => node[:fields].present? ? node[:fields] : []
        }
      else
        field_tooltip = if node[:description].nil?
                          "#{@root[:field_types][node[:typ]]}: #{node[:label]}"
                        else
                          "#{@root[:field_types][node[:typ]]}: #{node[:description]}"
                        end
        {:id => "#{parent[:id]}_#{node[:id]}",
         :text => node[:label] || _('[New Element]'),
         :image => "dialog_field",
         :tip => field_tooltip,
         :expand => true,
         :children => []
        }
      end
    end
    count_only ? nodes.size : nodes
  end
end
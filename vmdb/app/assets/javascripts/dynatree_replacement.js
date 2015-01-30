var dynatreeReplacement = {
  replace: function(options) {
    var onDblClickFunction;
    var onClickFunction;
    var onActivateFunction;
    var onSelectFunction;
    var onExpandFunction;
    var onLazyReadFunction;
    var onPostInitFunction;
    var selectMode;

    if (options.group_changed)
      cfme_delete_dynatree_cookies();

    if (options.no_base_exp) {
      onDblClickFunction = cfmeOnDblClick_NoBaseExpand;
    } else if (options.open_close_all_on_dbl_click) {
      onDblClickFunction = cfmeOnDblClick_Expand;
    }

    if (options.three_checks)
      selectMode = 3;

    if (options.cfme_no_click) {
      onClickFunction = function(node, event) {
        var event_type = node.getEventTargetType(event);
        if (event_type != 'expander') return false; //skip clicking on title when no event has been passed in
      };
    } else if (options.onclick || options.disable_checks || options.oncheck) {
      var optionsClickFunction = options.onclick;
      var optionsDisableChecks = options.disable_checks;
      var optionsOnCheckFunction = options.oncheck;
      var tree_name = options.tree_name;
      var click_url = options.click_url;

      if (optionsClickFunction) {
        if (click_url) {
          onClickFunction = function(node, event) {
            var event_type = node.getEventTargetType(event);
            if (event_type == 'icon' || event_type == 'title' || event.target.localName == 'img') {
              if (node.isActive()) {
                window[optionsClickFunction](node.data.key);
                return;
              }
            }
          };
        } else {
          if (miqCheckForChanges() === false) {
            onClickFunction = function(node, event) {
              var event_type = node.getEventTargetType(event);
              if (event_type == 'icon' || event_type == 'title' || event.target.localName == 'img') {
                this.activeNode.focus();
                return false;
              }
            };
          } else {
            onClickFunction = function(node, event) {
              var event_type = node.getEventTargetType(event);
              if (event_type == 'icon' || event_type == 'title' || event.target.localName == 'img') {
                if (node.isActive()) {
                  window[optionsClickFunction](node.data.key);
                  return;
                }
              }
            };
          }
        }
      }

      if (optionsDisableChecks || optionsOnCheckFunction) {
        if (optionsDisableChecks) {
          // Ignore checkbox clicks
          onclickFunction = function(node, event) { return false; };
        } else if (optionsOnCheckFunction) {
          onclickFunction = function(node, event) {
            var event_type = node.getEventTargetType(event);
            if (event_type == 'checkbox') {
              window[optionsOnCheckFunction](node, tree_name);
              return;
            }
          };
        }
      }

      if (optionsClickFunction) {
        onActivateFunction = function(node) {
          window[optionsClickFunction](node.data.key);
        };
      }

      if (options.onmousein || options.onmouseout) {
        onExpandFunction = function(node){
          cfme_bind_hover_event(options.tree_name);
        };
      }
    }

    if (options.onselect) {
      onSelectFunction = function(flag, node) {
        var selectedNodes = node.tree.getSelectedNodes();
        var selectedKeys = $.map(selectedNodes, function(node){
          return node.data.key;
        });
        window[options.onselect](options.tree_name, node.data.key, flag, selectedKeys);
        return;
      };
    }

    if (options.autoload) {
      onLazyReadFunction = function(node) {
        cfmeOnLazyRead_GetNodeChildren(node, options.tree_name, options.controller_name);
      };
    }

    // Activate silently (no onActivate event) selected node AFTER the tree is initially loaded or replaced by AJAX
    if (options.explorer && options.tree_name === options.x_active_tree) {
      onPostInitFunction = function(isReloading, isError) {
        cfmeDynatree_activateNodeSilently(options.tree_name, options.select_node);
      };
    }

    $('#' + options.tree_id).dynatree({
      checkbox: options.checkboxes,
      children: JSON.parse(options.json_tree),
      cookieId: options.cookie_id_prefix + options.tree_name,
      cookie: {path: "/"},
      generateIds: true,
      idPrefix: options.id_prefix,
      imagePath: '/images/icons/new/',
      minExpandLevel: options.min_expand_level,
      onActivate: onActivateFunction,
      onClick: onClickFunction,
      onDblClick: onDblClickFunction,
      onExpand: onExpandFunction,
      onLazyRead: onLazyReadFunction,
      onPostInit: onPostInitFunction,
      onSelect: onSelectFunction,
      persist: options.tree_state,
      selectMode: selectMode,
      title: options.tree_name,

      debugLevel: 0
    });

    $('#' + options.tree_id).dynatree('getTree').reload();

    if (options.expand_parent_nodes) {
      cfme_expand_parent_nodes(options.tree_name, options.expand_parent_nodes);
    }

    if (options.add_nodes && options.add_nodes[options.x_active_tree] && options.tree_name === options.x_active_tree) {
      cmfeAddNodeChildren(
        options.x_active_tree,
        options.add_nodes_x_active_tree_key,
        options.select_node,
        options.add_nodes_x_active_tree_children
      );
    }

    if (options.onmousein || options.onmouseout) {
      cfme_bind_hover_event(options.tree_name);
    }
  }
};

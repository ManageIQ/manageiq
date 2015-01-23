// Functions used by CFME for the dynatree control

// OnCheck handler for the Role features tree
function cfmeOnClick_RoleFeatureCheck(node) {
  if (node.isSelected())
    var checked = '0';  // If node was selected, now unchecking
  else
    var checked = '1';
  var url = check_url + node.data.key + '?check=' + checked
  miqJqueryRequest(url);
}

// Expand/collapse all children on double click
function cfmeOnDblClick_Expand(node, event) {
  if (node.isExpanded())
    var exp = false;
  else
    var exp = true;
  node.expand(exp);
  node.visit(function(n){n.expand(exp);});
}

function cfmeAddNodeChildren(treename, key, selected_node, children){
  var pnode = $j("#" + treename + "box").dynatree('getTree').getNodeByKey(key);
  pnode.addChild(children);
  cfmeDynatree_activateNodeSilently(treename, selected_node);
}

function cfmeRemoveNodeChildren(treename, key){
  var pnode = $j("#" + treename + "box").dynatree('getTree').getNodeByKey(key);
  pnode.removeChildren();
}

// Get children of a tree node via ajax for autoload
function cfmeOnLazyRead_GetNodeChildren(node, tree, controller) {
  node.appendAjax({
    url: "/" + controller + "/tree_autoload_dynatree",
    type: 'post',
    data: {"id": node.data.key, // Optional url arguments
      "tree": tree,
      "mode": "all"
    },
    success: function(node) {
      if(["cluster_dc_tree", "dc_tree", "rp_dc_tree", "vt_tree"].indexOf(tree) >= 0 ){
        //need to bind hover event to lazy loaded nodes
        cfme_bind_hover_event(tree)
        var url = '/' + controller + '/tree_autoload_quads?id=' + node.data.key
        miqJqueryRequest(url, {beforeSend: true});
      }
    }
  });
}

function miqMenuEditor(id) {
    nid = id.split('__');
    if(nid[0]!='r') {
      var url = click_url + '?node_id=' + encodeURIComponent(id) + '&node_clicked=1'
      miqJqueryRequest(url, {beforeSend: true,
        complete: true,
        no_encoding: true
      });
    }
}

// Bind hover events to the tree's <a> tags
function cfme_bind_hover_event(tree_name) {
  $j("#" + tree_name + "box a").hover(function(){
    var node = $j.ui.dynatree.getNode(this);
    miqOnMouseIn_HostNet(node.data.key);
  }, function(){
    var node = $j.ui.dynatree.getNode(this);
    miqOnMouseOut_HostNet(node.data.key);
  });
}

// OnClick handler to run tree_select server method
function cfmeOnClick_SelectTreeNode(id) {
  rec_id = id.split('__')
  var url = '/' + miq_controller + '/tree_select/?id=' + rec_id[0];
  miqJqueryRequest(url, {beforeSend: true});
}

function cfmeOnClick_SelectDlgEditTreeNode(id) {
  rec_id = id.split('__')
  var url = 'tree_select/?id=' + rec_id[0]
  miqJqueryRequest(url, {beforeSend: true, complete: true});
}

// Activate and focus on a node within a tree given the node's key
function cfmeDynatree_activateNode(tree, key) {
  var node = $j("#" + tree + "box").dynatree('getTree').getNodeByKey(key);
  if (node != null) { // Only try to activate node if it is in the tree
    node.activate();
    node.focus();
  }
}

// Activate silently (no onActivate event) and focus on a node within a tree given the node's key
function cfmeDynatree_activateNodeSilently(tree, key) {
  var node = $j("#" + tree + "box").dynatree('getTree').getNodeByKey(key);
  if (node != null) { // Only try to activate node if it is in the tree
    node.activateSilently();
    node.expand();
    node.focus();
  }
}

// OnClick handler for catgories Tree
function miqOnClick_ProvLdapOus(id) {
  node = $j("#ldap_ous_treebox").dynatree("getTree").getNodeByKey(id)
  node.expand();
  node._activate(false, true);
  if (id.split('_-_').length > 1) {
    miqJqueryRequest(click_url + '?ou_id=' + id);
    return true;
  }
}

//expand all parent nodes of selected node on initial load
function cfme_expand_parent_nodes(treename, selected_node){
  node = $j("#" + treename + "box").dynatree("getTree").getNodeByKey(selected_node)
  node.makeVisible()
}

function cfme_dynatree_node_add_class(treename, key, klass){
  node = $j("#" + treename + "box").dynatree('getTree').getNodeByKey(key);
  node.data.addClass = klass;
  node.render();
}

function cfme_dynatree_node_remove_class(treename, key){
  node = $j("#" + treename + "box").dynatree('getTree').getNodeByKey(key);
  node.data.addClass = "";
  node.render();
}

function cfme_dynatree_redraw(treename){
  $j("#" + treename + "box").dynatree('getTree').redraw();
}

// OnCheck handler for the tags trees
function miqOnCheck_ProvTags(node, treename) {
  tree = $j("#" + treename + "box").dynatree("getTree")
  parent_key = node.data.cfme_parent_key
  var selectedNodes = tree.getSelectedNodes();
  var all_checked = $j.map(selectedNodes, function(node){
    return node.data.key;
  });

  // need to add or delete the node manually in all_checked array
  // node select transaction is run after AJAX response comes back
  // when treestate is set to true
  if (node.isSelected()){
    var idx = all_checked.indexOf(node.data.key);
    all_checked.splice(idx, 1);
  } else {
    all_checked.push(node.data.key)
  }

  for (var i = 0; i < all_checked.length; i++) {
    selected_node = $j("#" + treename + "box").dynatree("getTree").getNodeByKey(all_checked[i])
    selected_node_parent_key = selected_node.data.cfme_parent_key
    if(typeof parent_key != "undefined"){
      // only keep the key that came in for a single value tag category
      // delete previously selected keys from the single value category before sending them up
      if(selected_node_parent_key == parent_key && node.data.key != all_checked[i]){
        var idx = all_checked.indexOf(all_checked[i]);
        all_checked.splice(idx, 1);
        selected_node._select(false);
      }
    }
  }
  miqJqueryRequest(check_url + '?ids_checked=' + all_checked);
  return true;
}

function cfmeOnClick_SelectAETreeNode(id) {
  miqJqueryRequest('/' + miq_controller + '/ae_tree_select/?id=' + id + '&tree=automate_tree');
}

function cfmeOnClick_SelectOptimizeTreeNode(id) {
    if ($j('#miq_capacity_utilization').length == 1)
        tree = "utilization_tree"
    else if ($j('#miq_capacity_bottlenecks').length == 1)
        tree = "bottlenecks_tree"
    if (id.split('-')[1].split('_')[0] == 'folder' ) {
        cfmeDynatree_activateNodeSilently(tree, id)
        return;
    } else {
      rep_id = id.split('__')
      cfmeDynatree_activateNodeSilently(tree, rep_id)
      var url = "/miq_capacity/optimize_tree_select/?id=" + rep_id[0]
      miqJqueryRequest(url, {beforeSend: true});
    }
}

// delete specific dynatree cookies
function cfme_delete_dynatree_cookies(tree_prefix) {
  miqClearTreeState(tree_prefix);
}

//toggle expand/collapse all nodes in tree
function cfme_dynatree_toggle_expand(treename, expand_mode){
  $j("#" + treename + "box").dynatree("getRoot").visit(function(node){
    node.expand(expand_mode);
  });
}

// OnCheck handler for the Protect screen
function miqOnCheck_Protect(node, treename) {
  ppid = node.data.key.split('_').pop();
  var url = check_url + ppid + '?check=' + (node.isSelected() ? '0' : '1')
  miqJqueryRequest(url);
  return true;
}

// OnClick handler for the VM Snapshot Tree
function miqOnClick_snapshot_tree(id) {
  miqJqueryRequest(click_url + id, {beforeSend: true, complete: true});
  return true;
}

// Show the hidden quad icon div when mousing over VMs in the Host Network tree
function miqOnMouseIn_HostNet(id) {
  nid = hover_node_id(id);
  if (nid)  {                                         // and div id exists
    var node = $j('#' + id);                                  // Get html node
    var top = getAbsoluteTop(node);
    $j("#" + nid).css({top: (top-220) + "px"});       // Set quad top location
    $j("#" + nid).show();                                    // Show the quad div
    last_id = nid;                                    // Save current node id
  }
}

// For Host Network tree, clear selection and hide previously shown quad icon div
function miqOnMouseOut_HostNet(id) {
  if (hover_node_id(id)) {                     // and div id exists
    if (last_id != null) $j("#" + last_id).hide();           // Hide the quad div
  }
  return true;
}

function hover_node_id(id){
  var ids = id.split('|')[0].split('_');              // Break apart the node ids
  var nid = ids[ids.length - 1];                      // Get the last part of the node id
  return ((nid.split('-')[0] == 'v' ||                // Check for VM node
    nid.split('-')[0] == 'h')                         // or Host node
    && miqDomElementExists(nid)) ? nid : false
}

// OnClick handler for Host Network Tree
function miqOnClick_HostNet(id) {
  ids = id.split('|')[0].split('_');              // Break apart the node ids
  nid = ids[ids.length - 1].split('-');                      // Get the last part of the node id
  switch(nid[0]) {
  case 'v':
    DoNav("/vm/show/" + nid[1]);
    break;
  case 'h':
    DoNav("/host/show/" + nid[1]);
    break;
  case 'c':
    DoNav("/ems_cluster/show/" + nid[1]);
    break;
  case 'rp':
    DoNav("/resource_pool/show/" + nid[1]);
    break;
  default:
    break;
  }
}

// OnClick handler for Report Menu Tree
function cfmeOnClick_TimelineSelection(id) {
  if (id.split('__')[0] != 'p') {
    rep_id = id.split('__')
    miqJqueryRequest(click_url + '?id=' + rep_id[0], {beforeSend: true, complete: true});
  }
}

// OnCheck handler for the belongs to drift/compare sections tree
function miqOnCheck_Sections(tree_name, key, checked, all_checked) {
  var url = check_url + '?id=' + key + '&check=' + checked + '&all_checked=' + all_checked
  miqJqueryRequest(url);
  return true;
}

// OnClick handler for catgories Tree
function cfmeOnClick_TagCat(id) {
  if (id.split('__')[0] == 't') {
    miqJqueryRequest(click_url + '?id=' + id, {beforeSend: true, complete: true});
  }
}

// OnCheck handler for the SmartProxy Affinity tree
function cfmeOnClick_SmartProxyAffinityCheck(node) {
  if (node.isSelected())
    var checked = '0';  // If node was selected, now unchecking
  else
    var checked = '1';
  miqJqueryRequest(check_url + node.data.key + '?check=' + checked);
}

// OnClick handler for Genealogy Tree
function cfmeOnClick_GenealogyTree(id) {
  switch(hover_node_id(id)[0]) {
    case 'v':  //case for vm genealogy tree
      miqJqueryRequest(click_url + id, {beforeSend: true, complete: true});
      break;
  }
}

function cfmeGetChecked(node, treename) {
  var count = 0;
  tree = $j("#" + treename + "box").dynatree("getTree")
  var selectedNodes = tree.getSelectedNodes();
  var selectedKeys = $j.map(selectedNodes, function(checkedNode){
    return checkedNode.data.key;
  });
  if (!node.isSelected() ) { //Indicates that the current node is checked
    selectedKeys.push(node.data.key)
  }
  else if (node.isSelected() ) { //Indicates that the current node is unchecked
    var index = selectedKeys.indexOf(node.data.key);
    if (index > -1) {
      selectedKeys.splice(index, 1);
    }
  }
  count = selectedKeys.length
  if (miqDomElementExists('center_tb'))
    miqSetButtons(count, "center_tb");
  else
    miqSetButtons(count, "center_buttons_div");
  if (count > 0) {
    miqJqueryRequest(check_url + '?all_checked=' + selectedKeys, {beforeSend: true, complete: true});
  }
}

function cfmeCheckAll(cb, treename) {
  $j("#" + treename + "box").dynatree("getRoot").visit(function(node){
    //calling _select to avoid onclick event when check all is clicked
    node._select(cb.checked);
    });
  tree = $j("#" + treename + "box").dynatree("getTree")
  var selectedNodes = tree.getSelectedNodes();
  var selectedKeys = $j.map(selectedNodes, function(node){
    return node.data.key;
  });

  var count = selectedKeys.length
  if (miqDomElementExists('center_tb'))
    miqSetButtons(count, "center_tb");
  else if (miqDomElementExists('center_buttons_div'))
    miqSetButtons(count, "center_buttons_div");

  if (count > 0) {
    var url = check_url + '?check_all=' + cb.checked + '&all_checked=' + selectedKeys
    miqJqueryRequest(url);
  }
  return true;
}

function cfmeDynatree_expandNode(treename, key) {
  var node = $j("#" + treename + "box").dynatree('getTree').getNodeByKey(key);
  node.expand(true);
}

function cfmeOnDblClick_NoBaseExpand(node, event) {
  if(!node.getParent().data.title)
    return;
  else {
    if (node.isExpanded())
      var exp = false;
    else
      var exp = true;
    node.expand(exp);
  }
}

// OnClick handler for Server Roles Tree
function miqOnClick_ServerRoles(id) {
  typ = id.split('_')[0];         // Break apart the node ids
  switch(typ) {
    case 'server':
    case 'role':
    case 'asr':
      miqJqueryRequest(click_url + '?id=' + id, {beforeSend: true, complete: true});
      break;
  }
}

// OnCheck handler for the belongsto tagging trees on the user edit screen
function miqOnCheck_UserFilters(node, tree_name) {
  tree_typ = tree_name.split('_')[0];
  var checked = node.isSelected() ? '0' : '1'
  var url = check_url + node.data.key +"?check=" + checked + "&tree_typ=" + tree_typ
  miqJqueryRequest(url);
  return true;
}

//OnCheck handler for Check All checkbox on C&U collection trees
function miqCheck_CU_All(cb, treename) {
  $j("#" + treename + "box").dynatree("getRoot").visit(function(node){
    //calling _select to avoid onclick event when check all is clicked
    node._select(cb.checked);
  });
  tree = $j("#" + treename + "box").dynatree("getTree")
  var selectedNodes = tree.getSelectedNodes();
  var selectedKeys = $j.map(selectedNodes, function(node){
    return node.data.key;
  });
  var url = check_url + '?check_all=' + cb.checked + '&tree_name=' + treename
  miqJqueryRequest(url);
  return true;
}

// OnCheck handler for the C&U collection trees
function miqOnCheck_CU_Filters(tree_name, key, checked) {
  var url = check_url + '?id=' + key +'&check=' + checked + '&tree_name=' + tree_name;
  miqJqueryRequest(url);
  return true;
}

function miqMenuChangeRow(grid,action,click_url) {
  id = folder_list_grid.getSelectedId();
  var ids = folder_list_grid.getAllRowIds().split(',')
  var count = ids.length
  ret = false
  switch(action)
  {
    case "up":
      folder_list_grid.moveRowUp(id);
      break;
    case "top":
      temp_id = id
      temp_text = folder_list_grid.cellById(folder_list_grid.getSelectedRowId(), folder_list_grid.getSelectedCellIndex()).getValue();
      folder_list_grid.deleteRow(id);
      folder_list_grid.addRow(temp_id,temp_text,0)
      folder_list_grid.selectRowById(temp_id);
      break;
    case "bottom":
      temp_id = id
      temp_text = folder_list_grid.cellById(folder_list_grid.getSelectedRowId(), folder_list_grid.getSelectedCellIndex()).getValue();
      folder_list_grid.deleteRow(id);
      folder_list_grid.addRow(temp_id,temp_text,count+1)
      folder_list_grid.selectRowById(temp_id);
      break;
    case "down":
      folder_list_grid.moveRowDown(id);
      break;
    case "add":
      folder_list_grid.addRow("folder" + count,"New Folder",count+1)
      folder_list_grid.selectRowById("folder" + count,true,true,true);
      miqJqueryRequest('/report/menu_folder_message_display?typ=add', {no_encoding: true});
      break;
    case "delete":
      var selected_id = id.split('|-|')
      if(selected_id.length == 1){
        folder_list_grid.deleteRow(id);
      } else {
        miqJqueryRequest('/report/menu_folder_message_display?typ=delete');
      }
      break;
    case "serialize":
      var url = click_url + '?tree=' + encodeURIComponent(miqDhtmlxgridSerialize(folder_list_grid));
      miqJqueryRequest(url, {beforeSend: true, complete: true, no_encoding: true});
      ret = true;
      break;
    default:
      break;
  }
  return ret;
}

function cfmeSetAETreeNodeSelectionClass(id, prevId, bValidNode) {
  if(prevId != "")
    cfme_dynatree_node_remove_class("automate_tree", prevId);

  if(bValidNode == "true")
    cfme_dynatree_node_add_class("automate_tree", id, "ae-valid-node");
}

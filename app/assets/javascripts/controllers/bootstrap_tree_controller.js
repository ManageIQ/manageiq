ManageIQ.angular.app.controller('bootstrapTreeController', ['$http', '$scope', 'bootstrapTreeSubscriptionService', 'initialTreeData', function($http, $scope, bootstrapTreeSubscriptionService, initialTreeData) {
  var init = function() {
    updateTree(initialTreeData);
    $('#bootstrap-tree').treeview('selectNode', 0);

    bootstrapTreeSubscriptionService.subscribeToTreeUpdates(updateTree);
    bootstrapTreeSubscriptionService.subscribeToCancelClicks(selectRootNode);
    bootstrapTreeSubscriptionService.subscribeToDeselectTreeNodes(unselectAllNodes);
    bootstrapTreeSubscriptionService.subscribeToSingleItemSelected(selectSingleNode);
  };

  var updateTree = function(data) {
    $('#bootstrap-tree').treeview({
      collapseIcon: 'fa fa-angle-down',
      data: data,
      expandIcon: 'fa fa-angle-right',
      nodeIcon: 'fa fa-folder',
      showBorder: false,
      onNodeSelected: nodeSelectedCallback
    });
  };

  var nodeSelectedCallback = function(_event, data) {
    if (data.id) {
      $http.get('object_data/' + data.id).then(sendTreeClickedEvent);
    } else {
      $http.get('all_object_data').then(sendRootTreeClickedEvent);
    }
  };

  var sendTreeClickedEvent = function(response) {
    sendDataWithRx({eventType: 'treeClicked', response: response.data});
  };

  var sendRootTreeClickedEvent = function(response) {
    sendDataWithRx({eventType: 'rootTreeClicked', response: response.data});
  };

  var unselectAllNodes = function(_response) {
    var selectedNodes = $('#bootstrap-tree').treeview('getSelected');
    $('#bootstrap-tree').treeview('unselectNode', selectedNodes);
  };

  var selectSingleNode = function(response) {
    var rootNode = $('#bootstrap-tree').treeview('getNode', 0);
    angular.forEach(rootNode.nodes, function(node) {
      if (node.text === response) {
        $('#bootstrap-tree').treeview('selectNode', node.nodeId);
      }
    });
  };

  var selectRootNode = function() {
    $('#bootstrap-tree').treeview('selectNode', 0);
  };

  init();
}]);

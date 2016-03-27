miqHttpInject(angular.module('providersModule', ['ui.bootstrap', 'patternfly', 'miq.dialogs', 'miq.wizard'])).controller('deployProviderController',
    ['$rootScope', '$scope', '$timeout',
        function($rootScope, $scope, $timeout) {
            'use strict';

            $scope.data = {};
            $scope.deployComplete = false;
            $scope.deployInProgress = false;
            $scope.open_modal = function () {
                $scope.showDeploymentWizard = true;
            };
            var initializeDeploymentWizard = function () {
                $scope.data = {
                    providerName: '',
                    providerType: 'atomic',
                    provisionOn: 'existingVms',
                    newProviderType: 'rhev',
                    masterCount: 0,
                    nodeCount: 0,
                    cdnConfigType: 'satellite'
                };

                $scope.existingProviders = [
                    {
                        id: 1,
                        name: 'Existing Provider 1'
                    },
                    {
                        id: 2,
                        name: 'Existing Provider 3'
                    },
                    {
                        id: 3,
                        name: 'Existing Provider 4'
                    }
                ];
                $scope.data.existingProviderId = $scope.existingProviders[0].id;
                $scope.deploymentDetailsGeneralComplete = false;
                $scope.deployComplete = false;
                $scope.deployInProgress = false;
                $scope.nextButtonTitle = "Next >";
            };

            var startDeploy = function () {
                $scope.deployInProgress = true;
                $timeout(function () {
                    $scope.deployInProgress = false;
                    $scope.deployComplete = true;
                    $scope.nextButtonTitle = "Close";

                }, 5000);

            };

            $scope.nextCallback = function(step) {
                if (step.stepTitle == 'Review') {
                    if ($scope.deployComplete) {
                        return true;
                    } else if (!$scope.deployInProgress) {
                        startDeploy();
                    }
                    return false;
                } else {
                    return true;
                }
            };
            $scope.backCallback = function(step) {
                return true;
            };

            $scope.$on("wizard:stepChanged", function(e, parameters) {
                if (parameters.step.stepId == 'review') {
                    $scope.nextButtonTitle = "Deploy";
                } else {
                    $scope.nextButtonTitle = "Next >";
                }
            });


            $scope.showDeploymentWizard = false;
            var showListener =  function() {
                if (!$scope.showDeploymentWizard) {
                    initializeDeploymentWizard();
                    $scope.showDeploymentWizard = true;
                }
            };
            $rootScope.$on('deployProvider.show', showListener);

            $scope.cancelDeploymentWizard = function () {
                if (!$scope.deployInProgress) {
                    $scope.showDeploymentWizard = false;
                }
            };

            $scope.$on('$destroy', showListener);


            $scope.cancelWizard = function () {
                $scope.showDeploymentWizard = false;
                return true;
            };

            $scope.finishedWizard = function () {
                $rootScope.$emit('deployProvider.finished');
                $scope.showDeploymentWizard = false;
                return true;
            };


            $scope.updateMasterCount = function (value) {
                if ($scope.data.masterCount + value >= 0) {
                    $scope.data.masterCount += value;
                }
            };
            $scope.updateNodesCount = function (value) {
                if ($scope.data.nodeCount + value >= 0) {
                    $scope.data.nodeCount += value;
                }
            };

            $scope.allNodes = [];
            $scope.filteredNodes = [];

            var matchesFilter = function (item, filter) {
                var match = true;

                if (filter.id === 'name') {
                    match = item.name.match(filter.value) !== null;
                } else if (filter.id === 'state') {
                    match = item.state === filter.value;
                }
                return match;
            };

            var matchesFilters = function (item) {
                var matches = true;

                $scope.filterConfig.appliedFilters.forEach(function (filter) {
                    if (!matchesFilter(item, filter)) {
                        matches = false;
                        return false;
                    }
                });
                return matches;
            };

            var applyFilters = function () {
                if ($scope.filterConfig.appliedFilters && $scope.filterConfig.appliedFilters.length > 0) {
                    $scope.filteredNodes = $scope.allNodes.filter(matchesFilters);
                } else {
                    $scope.filteredNodes = $scope.allNodes;
                }
            };

            var filterChange = function (filters) {
                applyFilters(filters);
                $scope.toolbarConfig.filterConfig.resultsCount = $scope.filteredNodes.length;
            };

            $scope.filterConfig = {
                fields: [
                    {
                        id: 'name',
                        title: 'Name',
                        placeholder: 'Filter by Name...',
                        filterType: 'text'
                    },
                    {
                        id: 'state',
                        title: 'State',
                        placeholder: 'Filter by State...',
                        filterType: 'select',
                        filterValues: ['Unset', 'Master', 'Node']
                    }
                ],
                resultsCount: $scope.filteredNodes.length,
                appliedFilters: [],
                onFilterChange: filterChange
            };

            var stateVals = {
                'Unset': 1,
                'Master': 2,
                'Node': 3
            };

            var compareFn = function (item1, item2) {
                var compValue = 0;
                if ($scope.sortConfig.currentField.id === 'name') {
                    compValue = item1.providerName.localeCompare(item2.providerName);
                } else if ($scope.sortConfig.currentField.id === 'state') {
                    compValue = stateVals[item1.state] - stateVals[item2.state];
                } else if ($scope.sortConfig.currentField.id === 'cpus') {
                    compValue = item1.cpus - item2.cpus;
                } else if ($scope.sortConfig.currentField.id === 'memory') {
                    compValue = item1.memory - item2.memory;
                } else if ($scope.sortConfig.currentField.id === 'diskSize') {
                    compValue = item1.diskSize - item2.diskSize;
                }

                if (!$scope.sortConfig.isAscending) {
                    compValue = compValue * -1;
                }

                return compValue;
            };

            var sortChange = function (sortId, isAscending) {
                $scope.filteredNodes.sort(compareFn);
            };

            $scope.sortConfig = {
                fields: [
                    {
                        id: 'name',
                        title: 'Name',
                        sortType: 'alpha'
                    },
                    {
                        id: 'state',
                        title: 'State',
                        sortType: 'alpha'
                    },
                    {
                        id: 'cpus',
                        title: '# CPUS',
                        sortType: 'numeric'
                    },
                    {
                        id: 'memory',
                        title: 'Memory',
                        sortType: 'numeric'
                    },
                    {
                        id: 'diskSize',
                        title: 'Disk Size',
                        sortType: 'numeric'
                    }
                ],
                onSortChange: sortChange
            };

            var performAction = function (action) {
            };

            $scope.actionsConfig = {
                primaryActions: [
                    {
                        name: 'Set as Master',
                        title: 'Set the selected items to be masters',
                        actionFn: performAction
                    },
                    {
                        name: 'Set as Node',
                        title: 'Set the selected items to be nodes',
                        actionFn: performAction
                    }
                ]
            };

            $scope.toolbarConfig = {
                filterConfig: $scope.filterConfig,
                sortConfig: $scope.sortConfig,
                actionsConfig: $scope.actionsConfig
            };


            //var providers = $resource('/containers/providers/nodes');
            //providers.get(function (data) {
            //    $scope.allNodes = data.data;
            //    applyFilters($scope.filterConfig.appliedFilters);
            //});

            var updateSetNodeTypeButtons = function () {
                var selectedCount = $scope.filteredNodes.filter(function(node) {
                    return node.selected;
                }).length;
                $scope.actionsConfig.primaryActions[0].isDisabled = $scope.data.masterCount === 0 ||
                    selectedCount === 0 ||
                    selectedCount > $scope.data.masterCount;
                $scope.actionsConfig.primaryActions[1].isDisabled = $scope.data.nodeCount === 0 ||
                    selectedCount === 0 ||
                    selectedCount > $scope.data.nodeCount;
            };

            $scope.allNodesSelected = false;
            $scope.toggleAllNodesSelected = function() {
                $scope.allNodesSelected = !$scope.allNodesSelected;
                $scope.filteredNodes.forEach(function (item, index) {
                    item.selected = $scope.allNodesSelected;
                });
                updateSetNodeTypeButtons();
            };

            $scope.toggleNodeSelected = function(node) {
                node.selected = !node.selected;
                var found = $scope.filteredNodes.find(function(node) {
                    return !node.selected;
                });
                $scope.allNodesSelected = (found === undefined);
                updateSetNodeTypeButtons();
            };
            updateSetNodeTypeButtons();

            $scope.deploymentDetailsGeneralComplete = false;
            $scope.updateProviderName = function() {
                $scope.deploymentDetailsGeneralComplete = angular.isDefined($scope.data.providerName) && $scope.data.providerName.length > 0;
            };
        }
    ]);

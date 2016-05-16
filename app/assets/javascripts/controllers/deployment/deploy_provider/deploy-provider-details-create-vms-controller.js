miqHttpInject(angular.module('miq.containers.providersModule')).controller('containers.deployProviderDetailsCreateVMsController',
    ['$rootScope', '$scope', '$timeout',
        function ($rootScope, $scope, $timeout) {
            'use strict';

            $scope.autoFillMasterAttributes = function (template) {
                $scope.data.createMastersMemory = template.ui_cpu;
                $scope.data.createMastersCpu = template.ui_memo;
            };

            $scope.provisionChanged();
            $scope.data.createMastersCount = 1;
            $scope.data.createNodesCount = 1;
            $scope.data.masterCreationTemplateId = $scope.data.nodeCreationTemplates[0].id;
            $scope.data.nodeCreationTemplateId = $scope.data.nodeCreationTemplates[0].id;
            $scope.data.createNodesLikeMasters = true;

            var validString = function (value) {
                return angular.isDefined(value) && value.length > 0;
            };

            $scope.validateForm = function () {
                var valid = $scope.masterCountValid($scope.data.createMastersCount) && $scope.nodeCountValid($scope.data.createNodesCount);

                valid = valid &&
                    validString($scope.data.createMasterBaseName) &&
                    validString($scope.data.createMastersMemory) &&
                    validString($scope.data.createMastersCpu) &&
                    validString($scope.data.createMastersNetwork) &&
                    validString($scope.data.createNodesBaseName);


                if (!$scope.data.createNodesLikeMasters) {
                    valid = valid &&
                        validString($scope.data.createNodesMemory) &&
                        validString($scope.data.createNodesCpu) &&
                        validString($scope.data.createNodesNetwork);
                }

                $scope.setMasterNodesComplete(valid);
            };

            $scope.updateNodesLikeMaster = function () {
                autoFillMasterAttributes(template);
                if ($scope.data.createNodesLikeMasters) {
                    $scope.data.nodeCreationTemplateId = $scope.data.masterCreationTemplateId;
                    $scope.data.createNodesMemory = $scope.data.createMastersMemory;
                    $scope.data.createNodesCpu = $scope.data.createMastersCpu;
                    $scope.data.createNodesNetwork = $scope.data.createMastersNetwork;
                }
                $scope.validateForm();
            };

            $scope.masterCountIncrement = function () {
                if ($scope.data.createMastersCount <= 3) {
                    $scope.data.createMastersCount += 2;
                }
            };
            $scope.masterCountDecrement = function () {
                if ($scope.data.createMastersCount > 1) {
                    $scope.data.createMastersCount -= 2;
                }
            };
            $scope.nodeCountIncrement = function () {
                $scope.data.createNodesCount += 1;
            };
            $scope.nodeCountDecrement = function () {
                if ($scope.data.createNodesCount > 1) {
                    $scope.data.createNodesCount -= 1;
                }
            };
        }
    ]);
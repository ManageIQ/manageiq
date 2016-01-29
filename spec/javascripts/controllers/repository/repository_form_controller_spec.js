describe('repositoryFormController', function() {
  var $scope, $controller, miqService;

  beforeEach(module('ManageIQ'));

  beforeEach(inject(function($rootScope, _$controller_, _miqService_) {
    miqService = _miqService_;
    spyOn(miqService, 'miqFlash');
    spyOn(miqService, 'miqAjaxButton');
    spyOn(miqService, 'sparkleOn');
    spyOn(miqService, 'sparkleOff');
    $scope = $rootScope.$new();
    $scope.repoModel = { repo_name: 'name', repo_path: 'path' };
    $scope.repositoryForm = { repo_name: {},
                              repo_path: {
                                $dirty:       false,
                                $name:       'repo_path',
                                $setValidity: function (validationErrorKey, isValid){}
                              },
                              $setPristine: function (){}
                            };

    $scope.repositoryForm.$invalid = false;
    repositoryData = {data: {repo_name: '',
                             repo_path: ''}
                     };
    $controller = _$controller_('repositoryFormController', {
        $scope: $scope,
        repositoryFormId: 'new',
        miqService: miqService,
        repositoryData: repositoryData
      });
    }));

    describe('initialization', function() {
      describe('when the repositoryFormId is new', function() {
        it('sets the name to blank', function () {
          expect($scope.repoModel.repo_name).toEqual('');
        });
        it('sets the path to blank', function () {
          expect($scope.repoModel.repo_path).toEqual('');
        });
      });

      describe('when the repositoryFormId is an Id', function() {
        var repositoryData = {data: {repo_name: 'aaa',
                                     repo_path: '//aa/a1'}
                             };

        describe('when the filter type is all', function() {
          beforeEach(inject(function(_$controller_) {
            $controller = _$controller_('repositoryFormController', {$scope: $scope,
                                                                     repositoryFormId: '12345',
                                                                     repositoryData:repositoryData});
          }));

          it('sets the repo_name to the value returned from the http request', function() {
            expect($scope.repoModel.repo_name).toEqual('aaa');
          });

          it('sets the repo_path to the value returned from the http request', function() {
            expect($scope.repoModel.repo_path).toEqual('//aa/a1');
          });
        });
      });
    });
});

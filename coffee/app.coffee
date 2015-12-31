RESULTS_LIST_URL = 'https://raw.githubusercontent.com/langmark/langmark/pushes/results.txt'
RESULT_BASE_URL = 'https://raw.githubusercontent.com/langmark/langmark/pushes/results/'


app = angular.module('langmark', [])

app.controller 'MainController', ['$scope', '$http', ($scope, $http)->

  $scope.analyzers = {}
  $scope.currentAnalyzer = null
  $scope.currentFile = null
  $scope.files = []

  $http.get(RESULTS_LIST_URL).then (response)->
    # Get all the results, ignore the white lines and the line starting with #
    results = response.data.split("\n").filter (x)->
      x != "" && x[0] != '#'

    for file in results
      $scope.analyzers[file] = new Analyzer(RESULT_BASE_URL + file, "[Travis] #{parseDate(file)}")
      $scope.files.push({ name: "[Travis] #{parseDate(file)}", file: file })

    # initialize the last file
    last = $scope.files[$scope.files.length-1]
    $scope.currentFile = last
    $scope.loadData(last.file)


  # load the specified file. If index is not specified use the selected one from the page
  $scope.loadData = (index)->
    index ?= $scope.currentFile.file

    $scope.analyzers[index].loadData $http, true, ->
      $scope.analyzers[index].draw()
      $scope.currentAnalyzer = $scope.analyzers[index]

  parseDate = (date)->
    year = date.slice(0, 4)
    month = date.slice(4, 6)
    day = date.slice(6, 8)
    hour = date.slice(8, 10)
    min = date.slice(10, 12)
    sec = date.slice(12, 14)

    return "#{day}/#{month}/#{year} at #{hour}:#{min}:#{sec}"
]
class @Hisogram
  options: null
  chart: null
  views: null
  currentView: null

  constructor: (data, title = '')->
    @options =
      title: title
      width: '100%'
      height: 400
      chartArea: { width: '90%', height: '80%' }
      legend: { position: 'none' }
      backgroundColor: "#eee"
      animation: { duration:500 }
      tooltip: { isHtml: true }
      logScale: false

    @views = []
    for index,view of data
      @views[index] = view

  # Set the container of the chart. container is a jQuery object which will be
  # populated with a button and a div with the chart
  setContainer: (container)->
    @currentView = 0
    chartDiv = $('<div>')

    slow = $('<button>').addClass('btn btn-success btn-xs').text('Hide slow')
    slow.click =>
      slow.toggleClass('btn-success').toggleClass('btn-primary')
      if @currentView == 0
        slow.text('Show slow')
        @draw(1)
      else
        slow.text('Hide slow')
        @draw(0)

    log = $('<button>').addClass('btn btn-success btn-xs').text('Log scale')
    log.click =>
      log.toggleClass('btn-success').toggleClass('btn-primary')
      if @options.logScale
        log.text('Linear scale')
        @options.logScale = 0
        @draw(@currentView)
      else
        log.text('Log scale')
        @options.logScale = 1
        @draw(@currentView)

    container.append(slow)
    container.append(log)
    container.append(chartDiv)
    @chart = new google.visualization.ColumnChart(chartDiv[0])

  # Draw the chart in a container (DOM object). view_idx is the index of the
  # data to draw
  draw: (view_idx = 0)->
    @chart.draw(@views[view_idx], @options)
    @currentView = view_idx




class @Lang
  times: []

  constructor: (@times)->

  # Get the minimum time of the test
  getMin: ->
    best = Infinity
    for compiler in @times
      best = Math.min(best, compiler.time)
    return best

  # Get the average time of the test
  getAverage: ->
    sum = 0
    for compiler in @times
      sum += compiler.time
    return sum/@times.length

  # Return a row valid for the DataTable. name is the language name, cols is
  # the number of data columns in the chart
  getRow: (name, cols)->
    # shift the columns to right to center them
    shift = ((cols - @times.length) / 2) | 0
    row = [name]
    for i in [0...cols]
      if i < shift || i >= shift + @times.length
        row.push [ 0, '']  # empty columns (aka hidden)
      else
        tooltip = "
          <div class='column-tooltip'>
            <h1>#{@times[i-shift].name}</h1>
            <dl>
              <dt>Version</dt>
              <dd>#{@times[i-shift].version.replace("\n", "<br>")}</dd>
              <dt>Time</dt>
              <dd>#{@times[i-shift].time.toFixed(3)}</dd>
            </dl>
        "
        row.push [ @times[i-shift].time, tooltip ]
    return row




class @Test
  name: ''
  langs: {}
  chart: null

  constructor: (@name, langs)->
    for lang,times of langs
      @langs[lang] = new Lang(times) if times.length > 0

    @chart = @getHistogram()

  # Get the average time of the test
  getAverage: ->
    sum = 0
    count = 0
    for _,tests of @langs
      sum += tests.getAverage()
      count++
    return sum / count

  # Return an histogram with 2 data series: the first with all languages and
  # the second with the languages faster than the average
  getHistogram: ->
    data = [ @getChartData(false), @getChartData(true) ]
    return new Hisogram(data)

  # Return the number of data columns
  getColsNumber: ->
    max = 0
    for lang,times of @langs
      max = Math.max(max, times.times.length)
    return max

  # Return a DataTable with the data of the test. When hide_slow is true the
  # slow languages are skipped
  getChartData: (hideSlow = false)->
    dataTable = new google.visualization.DataTable();

    cols = @getColsNumber()

    # add the columns to the DataTable
    dataTable.addColumn('string', 'Language')
    for i in [0...cols]
      dataTable.addColumn('number', '')
      dataTable.addColumn { type: 'string', role: 'tooltip', p: { html: true } }

    average = @getAverage() if hideSlow
    data = []
    for lang,times of @langs
      if hideSlow == false || times.getAverage() < average
        data.push times.getRow(lang, cols)

    # sort the data by the average time
    data = data.sort (a,b)->
      sum1 = count1 = sum2 = count2 = 0
      for i in [1...a.length]
        if a[i][0]
          sum1 += a[i][0]
          count1++
      for i in [1...b.length]
        if b[i][0]
          sum2 += b[i][0]
          count2++
      return sum1/count1 - sum2/count2

    # remove nested array
    parsedData = []
    for _,row of data
      parsedData.push [].concat.apply([], row)

    dataTable.addRows(parsedData)

    return dataTable




class @Table
  lang: null
  data: null

  constructor: (@lang, data)->
    @buildData(data)

  buildData: (data)->
    @data = {}
    for test,langs of data
      lang = langs[@lang]
      # skip a test if the language is missing
      continue unless lang
      # split the times by the compiler
      for i,compiler of lang
        @data[compiler.name] ?= {}
        @data[compiler.name][test] = compiler.time

  getTests: ->
    res = {}
    for compiler,tests of @data
      for test of tests
        res[test] = 1
    return Object.keys(res).sort()




class @Analyzer
  filename: null
  name: null
  data: null
  analyzed: null
  tests: null
  tables: null

  constructor: (@filename, @name)->
    @analyzed = false
    @tests = {}
    @tables = {}

  # Load the json with the result
  loadData: ($http, run_analysis = true, callback)->
    return callback() if @analyzed && callback

    $http.get(@filename).then (data)=>
      @data = data.data
      @analyze() if run_analysis
      callback() if callback

  # Begin the analysis of the data.
  # If this function was called before nothing happens
  analyze: ->
    return if @analyzed

    console.log("Analysis of #{@filename} started")

    for test,langs of @data
      @tests[test] = new Test(test, langs)

    @analyzed = true

  draw: ->
    @drawChart()
    @drawTable()

  drawChart: ->
    $('#container').empty()
    for _,test of Object.keys(@tests).sort()
      langs = @tests[test]

      div = $("<div>").attr('id', test)
      div.append(@getTitle(test))
      $('#container').append(div)
      langs.chart.setContainer(div)
      langs.chart.draw(0)

      $('#container').append('<br>')

  drawTable: ->
    for _,lang of @getLangs()
      @tables[lang] = new Table(lang, @data)

  getLangs: ->
    res = {}
    for test,langs of @data
      for lang of langs
        res[lang] = 1
    return Object.keys(res).sort()

  getTitle: (name)->
    a = $('<a href="#">')
    a.text(name)

    a.click =>
      $.ajax
        url: "https://raw.githubusercontent.com/langmark/langmark/master/#{name}/README.md"
        dataType: 'text'
        success: (data)->
          $('.modal-body').html(marked(data))
          $('.modal-title').text(name)
          $('#modal').modal()
        error: ->
          $('.modal-body').html('<em>No description available...</em>')
          $('.modal-title').text(name)
          $('#modal').modal()

    return $('<h2>').append(a)
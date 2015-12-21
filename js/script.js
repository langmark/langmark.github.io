RESULT_URL = 'https://raw.githubusercontent.com/langmark/langmark/pushes/results.txt';

ready = function() {
    var pool = {};

    function cmp_chart(a,b) {
        return a[1] - b[1];
    }

    function load_data() {
        $.ajax({
            url: RESULT_URL,
            type: 'GET',
            dataType: 'text',
            success: function(data) {
                var urls = data.split(/\r?\n/);
                var url = 'https://raw.githubusercontent.com/langmark/langmark/pushes/results/' + urls[urls.length - 2];
                $.ajax({
                    url: url,
                    type: 'GET',
                    dataType: 'json',
                    success: function(data) {
                        $('.wait-loaded').show();
                        $('.until-loading').hide();
                        process_data(data);
                        draw_graphs();
                    }
                });
            },
            error: function(err) {
                console.error('Ops.. Something went wrong', err);
            }
        });
    }

    function process_data(data) {
        pool.data = data;
        pool.per_test = {};
        pool.per_lang = {};
        pool.averages = {};

        for (var test in data) {
            for (var lang in data[test]) {
                if (data[test][lang].length == 0) continue;
                if (pool.per_lang[lang] == undefined) pool.per_lang[lang] = {};
                if (pool.per_test[test] == undefined) pool.per_test[test] = {};
                if (pool.averages[lang] == undefined) pool.averages[lang] = { sum: 0, count: 0 };

                var best = get_min(data[test][lang]);

                pool.per_test[test][lang] = best;
                pool.averages[lang].sum += best;
                pool.averages[lang].count++;

                for (var i in data[test][lang]) {
                    row = data[test][lang][i];

                    if (pool.per_lang[lang][row.name] == undefined)
                        pool.per_lang[lang][row.name] = {};

                    pool.per_lang[lang][row.name][test] = row.time;
                }
            }
        }
        console.log(pool);
    }

    function get_min(series) {
        var best = 100000;
        for (var i in series)
            best = Math.min(best, series[i].time);
        
        return best;
    }

    function draw_graphs() {
        average_graph();
        test_units();
        show_details();
    }

    function average_graph() {
        var viewAverageFull = null;
        var viewAverageFast = null;

        function get_views() {
            var sum = 0;
            var count = 0;
            for (var lang in pool.averages) {
                pool.averages[lang].time = pool.averages[lang].sum / pool.averages[lang].count;
                sum += pool.averages[lang].time;
                count++;
            }
            var average = sum / count;

            var dataFull = [ ['Lang', 'Time'] ];
            var dataFast = [ ['Lang', 'Time'] ];

            for (var lang in pool.averages) {
                dataFull.push([ lang, pool.averages[lang].time ]);
                if (pool.averages[lang].time <= average)
                    dataFast.push([ lang, pool.averages[lang].time ]);
            }
            dataFast.sort(cmp_chart);
            dataFull.sort(cmp_chart);

            viewAverageFull = new google.visualization.DataView(google.visualization.arrayToDataTable(dataFull));
            viewAverageFast = new google.visualization.DataView(google.visualization.arrayToDataTable(dataFast));
        }
        get_views();

        var options = {
            title: "",
            width: "100%",
            height: "400",
            chartArea: {'width': '90%', 'height': '80%'},
            legend: { position: "none" },
            backgroundColor: "#eee",
            animation: {duration:500}
        };

        var chart = new google.visualization.ColumnChart(document.getElementById("average_graph"));
        chart.draw(viewAverageFull, options);

        $("#averages_full").click(function() {
            var tag = $("#averages_full");
            if (tag.attr('data-status') == 'show') {
                chart.draw(viewAverageFast, options);
                tag.attr('data-status', 'hide').text('Show slow languages');
            } else {
                chart.draw(viewAverageFull, options);
                tag.attr('data-status', 'show').text('Hide slow languages');
            }
        });
    }

    function test_units() {
        for (var test in pool.per_test)
            add_test_unit(test, pool.per_test[test]);
    }

    function add_test_unit(test, data) {
        var viewAverageFull = null;
        var viewAverageFast = null;

        function get_views() {
            var sum = 0;
            var count = 0;
            for (var lang in data) {
                sum += data[lang];
                count++;
            }
            var average = sum / count;
            
            var dataFull = [ ['Lang', 'Time'] ];
            var dataFast = [ ['Lang', 'Time'] ];

            for (var lang in data) {
                dataFull.push([ lang, data[lang] ]);
                if (data[lang] <= average)
                    dataFast.push([ lang, data[lang] ]);
            }
            dataFast.sort(cmp_chart);
            dataFull.sort(cmp_chart);

            viewAverageFull = new google.visualization.DataView(google.visualization.arrayToDataTable(dataFull));
            viewAverageFast = new google.visualization.DataView(google.visualization.arrayToDataTable(dataFast));
        }
        get_views();


        var div = $('<div>');
        div.append('<h2>' + test);
        
        var graph = $('<div>').addClass('graph');
        var button = $('<span data-status="show">Hide slow languages</span>');
        graph.append(button);
        graph.append('<div id="graph_'+test+'" width="100%" height="400">');
        div.append(graph);

        $('#test_suites').append(div);
        
        var options = {
            title: '',
            width: "100%",
            height: "400",
            chartArea: {'width': '90%', 'height': '80%'},
            legend: { position: "none" },
            backgroundColor: "#eee",
            animation: {duration:500}
        };

        var chart = new google.visualization.ColumnChart(document.getElementById("graph_"+test));
        chart.draw(viewAverageFull, options);

        button.click(function() {
            if (button.attr('data-status') == 'show') {
                chart.draw(viewAverageFast, options);
                button.attr('data-status', 'hide').text('Show slow languages');
            } else {
                chart.draw(viewAverageFull, options);
                button.attr('data-status', 'show').text('Hide slow languages');
            }
        });
    }

    function show_details() {
        for (var lang in pool.per_lang)
            show_details_lang(lang, pool.per_lang[lang]);
    }

    function show_details_lang(lang, data) {
        var table = $('<table>');
        table.append(get_details_header);

        for (var comp in data)
            append_details_row(comp, data[comp], table);

        $('#details').append('<h2>' + lang);
        $('#details').append(table);
    }

    function get_details_header() {
        var row = $('<tr>');
        row.append('<th>Compiler/Interpreter');
        for (var test in pool.per_test)
            row.append('<th>'+test);
        return $('<thead>').append(row);
    }

    function append_details_row(comp, data, table) {
        var row = $('<tr>');
        row.append('<td>'+comp);
        for (var test in pool.per_test)
            row.append('<td>'+data[test]);
        
        table.append(row);
    }

    load_data();
}
google.load('visualization', '1.0', {'packages':['corechart']});
google.setOnLoadCallback(ready);

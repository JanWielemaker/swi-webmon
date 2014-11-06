:- module(monitor,
	  [ server/0,
	    monitor/0,
	    server/1
	  ]).
:- use_module(library(http/http_open)).
:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_parameters)).
:- use_module(library(http/html_write)).
:- use_module(library(http/js_write)).
:- use_module(library(http/html_head)).
:- use_module(library(http/http_server_files), []).
:- use_module(library(debug)).
:- use_module(library(apply)).
:- use_module(stat_lists).
:- use_module(library(http/http_error)).

:- debug(health).

:- http_handler(root(.),       overview, []).
:- http_handler(root(details), details,  []).

:- multifile
	user:file_search_path/2.

user:file_search_path(js, js).

:- html_resource(jquery,
		 [ virtual(true),
		   requires(js('jqplot/jquery.min.js'))
		 ]).
:- html_resource(
       jqplot,
       [ virtual(true),
	 ordered(true),
	 requires([ jquery,
		    js('jqplot/jquery.jqplot.min.js'),
		    js('jqplot/jquery.jqplot.css'),
		    js('jqplot/plugins/jqplot.canvasTextRenderer.min.js'),
		    js('jqplot/plugins/jqplot.canvasAxisLabelRenderer.min.js'),
		    js('jqplot/plugins/jqplot.dateAxisRenderer.min.js')
		  ])
       ]).

server :-
        server(3060).
server(Port) :-
        http_server(http_dispatch,
                    [ port(Port)
                    ]).

:- dynamic
	health/3.			% Service, Time, HealthState



		 /*******************************
		 *	       REPORT		*
		 *******************************/

overview(_Request) :-
	findall(Service-Health, health(Service, Health), Pairs),
	reply_html_page(
	    title('Service health'),
	    \overview(Pairs)).

overview(Pairs) -->
	overview_header,
	html(table(class(services),
		   [ \overview_table_header
		   | \overview_table_rows(Pairs)
		   ])).

overview_header -->
	html({|html||
<h1>Overview of monitored services</h1>
	     |}).

overview_table_header -->
	html(tr([ th('Service'),
		  th('Errors'),
		  th('Success'),
		  th('Min'),
		  th('Q1'),
		  th('Mean'),
		  th('Q3'),
		  th('Max')
		])).

overview_table_rows([]) --> [].
overview_table_rows([H|T]) --> overview_table_row(H), overview_table_rows(T).

overview_table_row(Name-Data) -->
	{ http_link_to_id(details, [service(Name)], HREF)
	},
	html(tr([ td(class(service), a(href(HREF),Name)),
		  td(class(errors),  Data.errors),
		  td(class(count),   Data.count),
		  td(class(min),     \time(Data.summary.min)),
		  td(class(q1),      \time(Data.summary.q1)),
		  td(class(mean),    \time(Data.summary.median)),
		  td(class(q3),      \time(Data.summary.q3)),
		  td(class(max),     \time(Data.summary.max))
		])).

time(Time) --> {number(Time)}, !, html('~3f'-[Time]).
time(Any) --> html('~p'-[Any]).

%%	details(+Request)
%
%	HTTP handler providing details for a service.

details(Request) :-
	http_parameters(Request,
			[ service(Service, []),
			  period(Hours, [default(24)])
			]),
	get_time(Now),
	After is Now - Hours*3600,
	reports(Service, After, Reports),
	partition(error, Reports, _Errors, Ok),
	maplist(time_at, Ok, Pairs),
	reply_html_page(
	    title('Details for service ~w'-[Service]),
	    [ \plot_header(Service),
	      \plot(Service, Pairs),
	      \plot_footer
	    ]).

time_at(Report, [Date,Time]) :-
	_{at:At, time:Time} :< Report,
	format_time(string(Date), '%F %T', At).

plot_header(ServiceName) -->
	html({|html(ServiceName)||
<h1>Details for service <span>ServiceName</span></h1>
	     |}).

plot_footer -->
	{ http_link_to_id(overview, [], Back) },
	html({|html(Back)||
<div class="footer">
Back to <a href=Back>overview</a>
</div>
	     |}).


plot(_Service, Series) -->
	{ PlotData = [Series],
	  Label1 = 'Time',
	  PlotID = plot
	},
	html_requires(jqplot),
	html(div([id(PlotID), style('height:250px;width:600px;')], [])),
	js_script(
	    {|javascript(PlotID, PlotData,Label1)||
$(document).ready(function(){
  var plot1 = $.jqplot(PlotID, PlotData,
		       { axesDefaults: {
			     labelRenderer: $.jqplot.CanvasAxisLabelRenderer
			 },
			 axes: { xaxis: { renderer:$.jqplot.DateAxisRenderer,
					  tickOptions:{formatString:'%H:%M'}
					},
				 yaxis: { label:Label1 }
			       },
			 series:[ {label:Label1}
				]
		       });
});
	    |}).




		 /*******************************
		 *	      COMPUTE		*
		 *******************************/

health(Name, _{count:Count, summary:Summary, errors:ErrorCount}) :-
	target(Service),
	Name = Service.name,
	get_time(Now),
	After is Now - 24*3600,
	reports(Name, After, Reports),
	length(Reports, Count),
	partition(error, Reports, Errors, Ok),
	length(Errors, ErrorCount),
	(   Ok == []
	->  Summary = _{min:(-), q1:(-), median:(-), q3:(-), max:(-)}
	;   maplist(get_dict(time), Ok, Times),
	    msort(Times, SortedTimes),
	    list_five_number_summary(SortedTimes, Summary)
	).

error(Report) :-
	Report.status \== true.

reports(Name, After, Reports) :-
	findall(Report, health_report(Name, After, Report), Reports).

health_report(Name, After, Report) :-
	health(Name, Time, Report0),
	Time >= After,
	Report = Report0.put(at, Time).


		 /*******************************
		 *	     MONITORING		*
		 *******************************/

%%	monitor
%
%	Monitor all target services.

:- dynamic
	monitor_thread/1.

monitor :-
	forall(retract(monitor_thread(Old)), collect(Old)),
	forall(target(Service),
	       ( thread_create(monitor(Service), Id, [alias(Service.name)]),
		 assertz(monitor_thread(Id)))
	       ).

collect(TID) :-
	thread_signal(TID, abort),
	thread_join(TID, _Status).

monitor(Service) :-
	forall(repeat,
	       ( check(Service),
		 sleep(Service.interval))).

check(Service) :-
	URL = Service.get(url),
	get_time(Now),
	test_health(fetch_url(URL), Service, Health),
	debug(health, '~q: ~p', [Service.name, Health]),
	assertz(health(Service.name, Now, Health)).

:- meta_predicate
	test_health(0, +, -).

test_health(Goal, Service, _{status:Status, time:Time}) :-
	get_time(T0),
	(   Timeout = Service.get(timeout)
	->  G = call_with_time_limit(Timeout, Goal)
	;   G = Goal
	),
	(   catch(G, E, true)
	->  (   var(E)
	    ->  Status = true
	    ;   Status = error(E)
	    )
	;   Status = false
	),
	get_time(T1),
	Time is T1-T0.

fetch_url(URL) :-
	setup_call_cleanup(
	    http_open(URL, In, []),
	    setup_call_cleanup(
		open_null_stream(Null),
		copy_stream_data(In, Null),
		close(Null)),
	    close(In)).

%%	target(-Service)is nondet.
%
%	Describe services to monitor.

target(_{name:'swi-prolog',
	 url:'http://www.swi-prolog.org/',
	 timeout:60,
	 interval:300
	}).

target(_{name:'search-swi-prolog',
	 url:'http://www.swi-prolog.org/search?for=current_output',
	 timeout:60,
	 interval:600
	}).

target(_{name:'swish',
	 url:'http://swish.swi-prolog.org/',
	 timeout:60,
	 interval:300
	}).

target(_{name:'swish-min.js',
	 url:'http://swish.swi-prolog.org/js/swish-min.js',
	 timeout:60,
	 interval:300
	}).



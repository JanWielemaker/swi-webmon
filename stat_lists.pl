/*  Part of ClioPatria SeRQL and SPARQL server

    Author:        Jan Wielemaker
    E-mail:        J.Wielemaker@cs.vu.nl
    WWW:           http://www.swi-prolog.org
    Copyright (C): 2010, University of Amsterdam,
		   VU University Amsterdam

    This program is free software; you can redistribute it and/or
    modify it under the terms of the GNU General Public License
    as published by the Free Software Foundation; either version 2
    of the License, or (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public
    License along with this library; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

    As a special exception, if you link this library with other files,
    compiled with a Free Software compiler, to produce an executable, this
    library does not by itself cause the resulting executable to be covered
    by the GNU General Public License. This exception does not however
    invalidate any other reasons why the executable file might be covered by
    the GNU General Public License.
*/

:- module(stat_lists,
	  [ list_mean/2,			  % +List, -Mean
	    list_variance/2,			  % +List, -Variance
	    list_sample_standard_deviation/2,	  % +List, -StDev
	    list_population_standard_deviation/2, % +List, -StDev
	    list_five_number_summary/2		  % +List, -FiveNumberSummary
	  ]).
:- use_module(library(lists)).
:- use_module(library(error)).

/** <module> Compute statistical properies of lists

This library computes statistical properties of lists of numbers.

@tbd	Fill it in ...
*/

%%	list_mean(+List, -Mean:float) is det.
%
%	True when Mean is the average value of amm numbers in List.
%
%	@error domain_error(non_empty_list, List) if List is [].

list_mean(List, Mean) :-
	list_length_mean(List, _Len, Mean).

list_length_mean(List, Len, Mean) :-
	length(List, Len),
	(   Len == 0
	->  domain_error(non_empty_list, List)
	;   sumlist(List, Sum),
	    Mean is Sum/Len
	).

%%	list_variance(+List, -Variance:float) is det.
%
%	True when Variance is the variance of List.
%
%	@error domain_error(non_empty_list, List) if List is [].

list_variance(List, Variance) :-
	list_mean(List, Mean),
	variance(List, Mean, 0, Variance).

variance([], _, V, V).
variance([H|T], Mean, V0, V) :-
	V1 is V0+(H-Mean)**2,
	variance(T, Mean, V1, V).

%%	list_population_standard_deviation(+List, -StDev:float) is det.
%
%	True if StDev is the _population_ standard deviation of List.
%	List must be non-empty.
%
%	@error domain_error(non_empty_list, List) if List is [].
%	@see list_sample_standard_deviation/2.

list_population_standard_deviation(List, StDev) :-
	list_length_mean(List, Len, Mean),
	variance(List, Mean, 0, Variance),
	StDev is sqrt(Variance/Len).

%%	list_sample_standard_deviation(+List, -StDev:float) is det.
%
%	True if StDev is the _sample_ standard deviation of List. List
%	must hold at least two elements.
%
%	@error domain_error(non_empty_list, List) if List is [].
%	@error domain_error(two_or_more_element_list, List) if List is [_].
%	@see list_population_standard_deviation/2.

list_sample_standard_deviation(List, StDev) :-
	list_length_mean(List, Len, Mean),
	(   Len == 1
	->  domain_error(two_or_more_element_list, List)
	;   true
	),
	variance(List, Mean, 0, Variance),
	StDev is sqrt(Variance/(Len-1)).

%%	list_median_(+SortedList, +Length, -Median, -Middle) is det.
%
%	Computes the median of the prefix with Length of SortedList.

list_median_(SortedList, Length, Median, Middle) :-
	Middle is Length div 2,
	nth0(Middle, SortedList, MiddleValue),
	Odd    is Length rem 2,
	(   Odd == 1
	->  Median = MiddleValue
	;   Middle0 is Middle - 1,
	    nth0(Middle0, SortedList, Middle0Value),
	    Median is (Middle0Value + MiddleValue) /2
	).


%%	list_five_number_summary(SortedList, Summary) is det.
%
%	If SortedList is sorted and has length > 1, Summary contains its
%	Tukey's five number summary:
%
%	    ==
%	    Summary = five_number_summary{ min:Minimum,
%					   q1:Q1,
%					   median:Median,
%					   q3:Q3,
%					   max:Maximum
%					 }
%	    ==
%
%	@see also: http://en.wikipedia.org/wiki/Five-number_summary

list_five_number_summary(SortedList, FiveNumSummary) :-
	FiveNumSummary = five_number_summary{min:Minimum, q1:Q1, median:Median, q3:Q3, max:Maximum},
	length(SortedList, Length),
	list_median_(SortedList, Length, Median, Middle),
	length(LastHalf, Middle),
	append(_, LastHalf, SortedList),!,
	(   list_median_(SortedList, Middle, Q1, _)
	->  true
	;   Q1 = Minimum
	),
	(   list_median_(LastHalf,   Middle, Q3, _)
	->  true
	;   Q3 = Maximum
	),
	SortedList = [Minimum|_],
	last(SortedList, Maximum).





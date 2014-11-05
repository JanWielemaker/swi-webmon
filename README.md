# Simple SWI-Prolog script to monitor web server performance

This is a little script to monitor the performance of several URLs which
provides a web frontend to see   overall statistics and detailed timing.
It was developed to examine  the   -sometimes-  poor  performance of the
SWI-Prolog web services.  To run it,

  - Install SWI-Prolog version 7 (the development version)
  - Run `swipl run.pl`
  - Browse to http://localhost:3060/

The monitored services are  specified  in   target/1  at  the  bottom of
monitor.pl.

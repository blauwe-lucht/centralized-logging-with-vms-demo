# Centralized logging with VMs demo

## Fibonacci calculator

<http://192.168.6.31>

## OpenSearch API

<https://192.168.6.33:9200/>

## Kibana

<http://192.168.6.33:5601>

Create index pattern fibonacci*

Refresh field list: Dashboard Management->Index patterns->select index pattern->Refresh field list

## Use cases

### Following a request over multiple logs using request ID

### Saving searches

### Filtering logs by level

Looking at log files that includes all levels (from TRACE to CRITICAL) is a lot of work.
Most of the time you're not interested in the lowest level of logging (until you find the proper spot to dive deeper).
Focussing on high levels first and then dig deeper into lower levels is very easy with Kibana:

- First add a filter that only shows warnings and errors
- Find the timestamp or request ID that has an issue
- Filter on that timestamp/request ID and open the filter so it shows lower level log events

TODO: hoe gaat ik dit proces laten zien in deze demo?
Fout introduceren bij specifiek request? Bv panic bij 27372.

### Creating dashboard from saved search

### Creating alert on number of errors

## Issues

Centralized logging is not a silver bullet, there are still some issues that make analyzing logs a challenge:

- Precision: tools like OpenSearch only store timestamps with one millisecond resolution. Within the same millisecond, the
order of events is not guaranteed.
- Clock skew: computer clocks of separate machines are not synchronized to within one millisecond. This means that causality is not preserved.
An example: event A happens on machine A which causes event B to happen on machine B. When B's clock is ahead of A's clock, the
log of event B may have an earlier timestamp than event A. So when looking at the combined logs it will look like event B
occurred before event A.

There are solutions for these issues:

- An extra field containing microseconds can be added to each event and the combination of timestamp and microseconds
can be used to sort the events properly.
- A protocol like [PTP](https://en.wikipedia.org/wiki/Precision_Time_Protocol) (Precision Time Protocol)
can be used to minimize the clock skew between computer clocks,
- or increasing sequence numbers can be added to events to make the order of events explicit.

In this demo these solutions were not implemented to keep the demo simple.

## TODO

- add X-request-id to nginx backend log
- create use cases
- automatic flushing of log file buffers
- field log has conflict in types

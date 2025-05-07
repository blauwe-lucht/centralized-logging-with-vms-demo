# Centralized logging with VMs demo

The IT world is moving towards cloud computing, but not every company is ready, willing or able.
However centralized logging is a powerful technique to get more value from log files and
make finding issues much easier.

This demo shows one set of tools that can be used to accomplish centralized logging in
VM (but also physical machines) environments:

- [Fluent Bit](https://fluentbit.io/): used to aggregate logging and send it to a central server,
- [OpenSearch](https://opensearch.org/): storage and indexing of log event,
- [OpenSearch Dashboards](https://www.opensearch.org/docs/latest/dashboards/): web UI to analyze and visualize information from log events.

## Prerequisites

- [VirtualBox](https://www.virtualbox.org/), tested with 7.0.20
- [Vagrant](https://www.vagrantup.com/), tested with 2.4.1

## Setup

```bash
vagrant up
```

This will take a while, so have some tea or coffee. When done, this will have created three VMs:

![Overview](images/overview.png)

A simple application is running as a distributed system:

- an Nginx reverse proxy for the frontend,
- a frontend application (running as a service) that serves simple HTML and forwards request to the backend that does the actual calculation,
- an Nginx reverse proxy for the backend,
- a backend application (also running as a service) that does the actual calculation.

In total this application generates six log files. These log files are read and parsed by Fluent Bit and then sent to OpenSearch.
OpenSearch stores and indexes each event. OpenSearch Dashboards can then be used to view and visualize the information from the logs.

## Teardown

```bash
vagrant destroy -f
```

Note that this will also remove all collected data.

However it will not remove the downloaded Vagrant boxes. To delete these as well you have to use extra commands:

```bash
vagrant box remove generic/alma8
vagrant box remove ubuntu/jammy64
```

## Generating logs

### Using the Fibonacci calculator

Point a browser to <http://192.168.6.31>, fill in some number and press 'Calculate'.

![Fibonacci Calculator](images/calculator.png)

### Using the test script

On the host, run

```bash
./test/test-setup.sh
```

This will also run some tests that check if logging is created correctly.

## View logs

### Using OpenSearch API

```bash
curl -k -X GET "https://192.168.6.33:9200/fibonacci-*/_search" \
-u 'admin:T!mberW0lf#92' \
-H "Content-Type: application/json"
```

### Using OpenSearch Dashboards

You'll get a much better experience when using OpenSearch Dashboards.
Point your browser at <http://192.168.6.33:5601>, login with user name ```admin``` and password ```T!mberW0lf#92```.
Click through the welcome screens.
Then press the hamburger menu in the top left and select Discover.
You need to create an index pattern manually (I couldn't get it to work automatically). Use Index Pattern Name 'fibonacci-*',
so all fibonacci log indices will be included. Select '@timestamp' as the time field.
Create the index pattern and return to the Discover screen.

## Scenarios

### Viewing log files the old way

- select specific component to view by entering '_index: fibonacci-backend-application*' in the search
- expand top document
- select which fields to see, for example level, message
- when needed, reverse the sort order on timestamp
- save search (top right)

### Following a request over multiple logs using request ID

- filter on error: add filter 'level is ERROR'
- expand document, select 'View surrounding documents'
- find related document with request ID
- change filter to 'request_id is \<request ID\>'
- filter out unwanted logging, like third party libraries

### Seeing errors appear live

- select ERROR logging or failed HTTP request by entering 'level:ERROR OR status:500' in the search
- set refresh to one second
- fill in 100 in the Fibonacci calculator and see the error appear within a couple of seconds
- save search to 'errors'

### See only HTTP requests

- find a document of an Nginx index
- expand the document
- left of the 'request_time' field click on 'Filter for field present'.
- save search

### See long HTTP requests

- as previous section
- add search 'request_time>1'
- save search to 'long-http-requests' (don't forget to select 'Save as new search')

### Create visualizations from saved searches

In the left top hamburger menu, select Visualize.

#### Number of errors per minute for the past day

- New Visualization
- select vertical bar
- select saved search 'errors'
- select Buckets, X-axis, Date Histogram, set minimum interval to one minute
- in the top right, change the range to 'Last 24 hours'
- save the visualization as 'error-count-per-time'

#### Number of long HTTP requests per minute for the past day

- New Visualization
- select vertical bar
- select saved search 'long-http-requests'
- select Buckets, X-axis, Date Histogram, set minimum interval to one minute
- in the top right, change the range to 'Last 24 hours'
- save the visualization as 'long-http-requests-per-time'

#### Show top 10 of longests HTTP requests

- New Visualization
- select 'Data table'
- select saved search 'long-http-requests'
- change metric from Count to Max, select field 'request_time'
- add a bucket, select 'split rows', set aggregation to 'Terms', use field 'request_time', set size to 10
- add a bucket, select 'split rows', set aggregation to 'Terms', use field 'path.keyword', set size to 10
- press Update
- save the Visualization as 'longest-http-requests'

### Creating dashboard from saved search

- In the top left hamburger menu chose Dashboards. Click 'create new'.
- Add panels from the saved searches.
- Save the dashboard.

### Creating alert on number of errors

TODO

## Issues

Centralized logging is not a silver bullet, there are still some issues that make analyzing logs a challenge:

- Clock skew: computer clocks of separate machines are not synchronized to within one millisecond. This means that causality is not fully preserved.
An example: event A happens on machine A which causes event B to happen on machine B. When B's clock is ahead of A's clock, the
log of event B may have an earlier timestamp than event A. So when looking at the combined logs it will look like event B
occurred before event A.

There are solutions for these issues:

- A protocol like [PTP](https://en.wikipedia.org/wiki/Precision_Time_Protocol) (Precision Time Protocol)
can be used to minimize the clock skew between computer clocks,
- or increasing sequence numbers can be added to events to make the order of events explicit.

In this demo these solutions were not implemented to keep the demo simple.

## Interesting stuff I had to figure out

- How to use microsecond precision timestamps in OpenSearch to preserve causality within one server.
- How to write Nginx access logs as json.
- How to write structured logging in Rust.
- How to let Nginx generate a request ID.
- How to pass that request ID through the whole chain.
- How to have Fluentbit properly parse Nginx error logs.
- How to have Fluentbit use the journal as input to read the logs of a single service.

## TODO

- create scenarios
- add target/source/component field for each component so it's possible to filter for example on only frontend-nginx-access lines

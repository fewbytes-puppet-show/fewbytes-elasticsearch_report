# elasticsearch_report

## Overview

A Puppet report plugin which reports to ElasticSearch and optimized for use with Kibana 4. 

## Setup

Just add the module to your `modulepath`

## Usage

Add the following to agent nodes `puppet.conf` file:

	[agent]
	report = true
	reports = store,log,elasticsearch

You can of course use the `main` or `user` sections as applicable.

Create `elasticsearch.yaml` config file in your puppet config dir (on agent nodes):

	---
	# default is http://localhost:9200/
	:elasticsearch_url: http://elasticsearch:9200/ 
	:index: puppet-%{%Y.%m.%d}
	:document_type: puppet_report


Note the `:` at the start of the Yaml keys. Just as with hiera config file, it is significant.
The index format will interpolate ruby time format within the `%{}` stanza. Note this contrasts with Logstash which uses JodaTime format strings. E.g. Logstash format would be `YYYY.MM.DD` where as the equivalent ruby format string is `%Y.%m.%d`.
Why did I use Ruby format? mainly because i'm lazy.

### ElasticSearch index template

It is **highly** recommended you use the index template in `report_index_template.json` file. You can load it to ElasticSearch using curl:

	curl -XPUT http://elasticsearch:9200/_template/puppet -d @report_index_template.json

The template will provide the appropriate document mapping which makes sure your index isn't horribly slow due to insane number of fields from `resource_status` section of the report.


## Development

If you want to fix something, add a feature or whatever, open an issue and/or a pull request.
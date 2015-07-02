require 'net/http'
require 'puppet'

Puppet::Reports.register_report(:elasticsearch) do
	desc "An Elasticsearch report processor, for use with Kibana4"

	def config
		return @config if @config
		
		config_file = File.join(File.dirname(Puppet.settings[:config]), "elasticsearch.yaml")
		raise(Puppet::ParseError, "Elasticsearch report config file #{config_file} not readable") unless File.exist?(config_file)
		@config = {
			:elasticsearch_url => "http://localhost:9200/",
			:index => "puppet-%{%Y.%m.%d}",
			:document_type => "puppet_report"
		}.merge(YAML.load_file(config_file))
	end

	def process
		uri = URI.parse(config[:elasticsearch_url])
		uri.path = "/#{es_index}/#{config[:document_type]}/#{document_id}"
		request = Net::HTTP::Post.new(uri.request_uri)
		request.body = report_body
		Puppet.debug("Report body: \n" + request.body)
		request['content-type'] = 'application/json'
		http = Net::HTTP.new(uri.host, uri.port)
		response = http.request(request)
		Puppet.debug("Submitting report to #{uri}")
		unless response.is_a? Net::HTTPSuccess
			Puppet.crit("Failed to submit report to Elasticsearch @ #{uri}, got response code #{response.code}")
		end
	end

	def es_index
		m = /^(.*)%{(.+)}(.*)$/.match(config[:index])
		if m
			date_pattern = m[2]
			m[1] + Time.now.strftime(m[2]) + m[3]
		else
			config[:index]
		end
	end

	def report_body
		{
			:host => self.host,
			:status => self.status,
			:configuration_version => self.configuration_version,
			:run_type => self.kind,
			:metrics => format_metrics,
			:logs => to_data_hash_recursive(logs),
			:changed_resources => changed_resources,
			:failed_resources => failed_resources,
			:time => self.time.iso8601,
			:transaction_uuid => self.transaction_uuid,
			:puppet_version => self.puppet_version,
			:environment => self.environment
		}.to_json
	end

	def document_id
		if config[:document_id]
			config[:document_id].gsub("%H", self.host).gsub("%V", self.configuration_version)
		else
			""
		end
	end

	def format_metrics
		Hash[self.metrics.map do |category, m|
			[
				category,
				Hash[m.values.map do |val|
					val.values_at(0, 2)
				end]
			]
		end]
	end

	def changed_resources
		resource_statuses.select do |k, r_status|
			r_status.changed
		end.map(&:first)
	end

	def failed_resources
		resource_statuses.select do |name, r_status|
			r_status.failed
		end.map(&:first)
	end

	def to_data_hash_recursive(obj)
		data_hash = if obj.respond_to?(:to_data_hash)
				obj.to_data_hash
			else
				obj
			end
		case data_hash
		when Array
			data_hash.map{|elmnt| to_data_hash_recursive(elmnt)}
		when Hash
			Hash[data_hash.map{|k, elmnt| [k, to_data_hash_recursive(elmnt)]}]
		else
			data_hash
		end
	end

end
#!/usr/bin/ruby

require 'rubygems'
require 'statsd'

class Hash
    def hmap(&block)
      self.inject({}){ |hash,(k,v)| hash.merge( block.call(k,v) ) }
    end
end

class Simulator 

	def initialize(host, port, interval)
		p host
		p interval
		@host = host
		@port = port
		@interval = interval
		@statsd = Statsd.new @host, @port
	end
	def run
		chargers = ["1130-1414-7569-4457-6613-5551", "1159-1414-7569-3493-5006-5653", "1016-0414-2428-7157-5404-6669", "1016-1415-6379-6184-1333-2468", "1118-0416-1130-3724-2927-7040"]
		fields = { 		electricity: 6..100, 
					voltage: 220..1000, 
					parking_lot_available: [0, 1], 
					power_consumption: 10000..20000, 
					temperature: 10..60,
				 }	
		previous_fields = fields.hmap { |k, v| { k.to_sym => v.min } }
		previous_increase = fields.hmap { |k, v| {k.to_sym => 1 }}

		previous_values = Hash.new
		previous_increases = Hash.new

		chargers.each do |h|
			previous_values[h] = previous_fields.clone
			previous_increases[h] = previous_increase.clone
		end
		t = nil	
		par = Random.new.rand(3..6)
		par_time = 3600 / par
		chargers.each do |c|
			fields.each do |f, v|
				t = Thread.new("#{c}.#{f}") do			
					loop do
						simulate(c, f, v, par_time, previous_values, previous_increases)
						sleep @interval
					end # loop
				end # thread	
			end # fields
		end #chargers
		t.join		
	end #run
	
	def simulate(c, f, v, par_time, previous_values, previous_increases)
		if v.kind_of? Array
			value = v.sample
		else	
			point_distance = (v.max - v.min) / (par_time / 5.0)
			delta = Random.new.rand(point_distance / 2..point_distance * 2)
			delta = -delta unless previous_increases[c][f] == 1
			value = previous_values[c][f] + delta
			if Random.new.rand(8) == 1
				value = previous_values[c][f] + delta * 10  
				previous_values[c][f] = value 
			end
			if Random.new.rand(8) == 1
				value = previous_values[c][f] - delta * 5  
				previous_values[c][f] = value 
			end
			if Random.new.rand(5) == 1
				value = previous_values[c][f] - delta 
				previous_values[c][f] = value 
			end
		end
		previous_values[c][f] = value
		previous_increases[c][f] = 0 if value >= v.max 
		previous_increases[c][f] = 1 if value <= v.min || value <= 0
		# We will devide 100 in the server side while taking the number since Statsd doesn't support decimal numbers
		final_value = value.to_i
		final_value = value.to_i * 100 + Random.new.rand(100) unless v.kind_of? Array
		puts "#{c}:#{f}....#{final_value}" 
		@statsd.timing "charger.#{c}.#{f}", final_value	 	
	end
end

server = ARGV[0]
server = '127.0.0.1' unless server
interval = ARGV[1]
interval = 5 unless interval

Simulator.new(server, 8125, interval).run 

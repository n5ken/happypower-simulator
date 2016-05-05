#!/usr/bin/ruby

require 'rubygems'
require 'statsd'


class Simulator 

	def initialize(host, port)
		@host = host
		@port = port
		@statsd = Statsd.new @host, @port
	end


	def run
		chargers = ["1130-1414-7569-4457-6613-5551", "1159-1414-7569-3493-5006-5653", "1016-0414-2428-7157-5404-6669", "1016-1415-6379-6184-1333-2468", "1118-0416-1130-3724-2927-7040"]	
		fields = { 	electricity: 6..100, 
					voltage: 220..1000, 
					parking_lot_available: [0, 1], 
					power_consumption: 10000..20000, 
					temperature: 10..60
				 }

		loop do
			p "sending data"

			chargers.each do |c|
				fields.each do |f, v|
					p f
					if v.kind_of? Array
						value = v[Random.new.rand(v.length)]	
						value *= 100
					else
						value = Random.new.rand(v) 
						value *= 100
						value += Random.rand(100)
					end
					# We will devide 100 in the server side while taking the number since Statsd doesn't support decimal numbers
					@statsd.timing "charger.#{c}.#{f}", value
				end	
			end

			sleep 2 	
		end

	end

end


Simulator.new('127.0.0.1', 8125).run 

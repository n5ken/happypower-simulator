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
		chargers = ["SMART_LINK_00123456ABCDEF", "SMART_LINK_00123456ABCDEE"]
		fields = { 		a_phase_current: 0..100, 
					b_phase_current: 0..100, 
					c_phase_current: 0..100, 
					total_current: 0..100, 
					a_phase_volt: 220..1000,
					b_phase_volt: 220..1000,
					c_phase_volt: 220..1000,
					total_volt: 220..1000,
					a_phase_active_power: 0..0,
					b_phase_active_power: 0..0,
					c_phase_active_power: 0..0,	
					total_active_power: 0..0,
					total_positive_active_energy: 0..0, 
					a_phase_power_factor: 50..90, 
					b_phase_power_factor: 50..90, 
					c_phase_power_factor: 50..90, 
					total_power_factor: 50..90, 
					frequency: 45..55, 
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
		@first_run = 1
		par = 2
		par_time = 300 / par
		@time_begin, @time_run = 0, 0
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
			#point_distance = (v.max - v.min) / (par_time / 5.0)
			#delta = Random.new.rand(point_distance / 2..point_distance * 2)
			#delta = -delta unless previous_increases[c][f] == 1
			#value = previous_values[c][f] + delta
			if @first_run == 1
				@time_begin = Time.now.to_i
				@first_run = 0
			end
			@time_run = Time.now.to_i
			test = @time_run - @time_begin
			if test > par_time / 2 and test < par_time || test > 2 * par_time and test > 3/2 * par_time
				unless f == :a_phase_power_factor || f == :b_phase_power_factor || f == :c_phase_power_factor || f == :total_power_factor || f == :frequency || f == :temperature
					if f == :a_phase_current || f == :b_phase_current || f == :c_phase_current || f == :total_current
							if previous_increases[c][f] == 1 		
								previous_values[c][f] = previous_values[c][f] + Random.new.rand(80..100) unless f == :total_current 
								previous_values[c][f] = previous_values[c][:a_phase_current] + previous_values[c][:b_phase_current] + previous_values[c][:c_phase_current] if f == :total_current
								previous_increases[c][f] = 0
							else
								previous_values[c][f] = previous_values[c][f] - 0.089 unless f == :total_current
								previous_values[c][f] = previous_values[c][:a_phase_current] + previous_values[c][:b_phase_current] + previous_values[c][:c_phase_current] if f == :total_current

							end	
					end
					if f == :a_phase_volt || f == :b_phase_volt || f == :c_phase_volt || f == :total_volt
						previous_values[c][f] == Random.new.rand(198..242) unless f == :total_volt
						previous_values[c][f] == (:a_phase_volt + :b_phase_volt + :c_phase_volt) * 3 / 1.732 if f == :total_volt
					end
					if f == :a_phase_active_power || f == :b_phase_active_power || f == :c_phase_active_power || f == :total_active_power
						previous_values[c][f] = previous_values[c][:a_phase_current] * previous_values[c][:a_phase_volt] * 1.732 if f == :a_phase_active_power 
						previous_values[c][f] = previous_values[c][:b_phase_current] * previous_values[c][:b_phase_volt] * 1.732 if f == :b_phase_active_power 
						previous_values[c][f] = previous_values[c][:c_phase_current] * previous_values[c][:c_phase_volt] * 1.732 if f == :c_phase_active_power 
						previous_values[c][f] = previous_values[c][:a_phase_active_power] + previous_values[c][:b_phase_active_power] + previous_values[c][:c_phase_active_power] if f == :total_active_power 
					end
					previous_values[c][f] = previous_values[c][:total_active_power] * 1/3600 if f == :total_positive_active_energy
				end
			else
				previous_values[c][f] = 0 if f == :a_phase_current || f == :b_phase_current || f == :c_phase_current || f == :total_phase_current
				previous_increases[c][f] = 1 if f == :a_phase_current || f == :b_phase_current || f == :c_phase_current
			end
	
		previous_values[c][f] = Random.new.rand(198..242) if f == :a_phase_volt || f == :b_phase_volt || f == :c_phase_volt 
                previous_values[c][f] = (:a_phase_volt + :b_phase_volt + :c_phase_volt) * 3 / 1.732 if f == :total_volt
		previous_values[c][f] = Random.new.rand(0..1) if f == :a_phase_power_factor ||  f == :b_phase_power_factor || f == :c_phase_power_factor  || f == :total_power_factor
		previous_values[c][f] = Random.new.rand(45..55) if f == :frequency
		previous_values[c][f] = Random.new.rand(30..60) if f == :temparature 
		puts "key:meter.#{c}.#{f}.......value:#{previous_values[c][f]}" 
		@statsd.timing "meter.#{c}.#{f}", previous_values[c][f] * 100	
	end
end

server = ARGV[0]
server = '127.0.0.1' unless server
interval = ARGV[1]
interval = 5 unless interval

Simulator.new(server, 8125, interval).run 

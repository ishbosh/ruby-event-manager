require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def clean_phone_number(phone_number)
  phone_string = phone_number.to_s.delete('^0-9')

  if phone_string.length == 10
    phone_string
  elsif phone_string.length == 11 && phone_string[0] == 1
    phone_string[1..10]
  else  
    'Bad Number'
  end
end

def get_date(date_time)
  date_time.split[0]
end

def get_time(date_time)
  date_time.split[1]
end

def clean_date(date)
  Date.strptime(date, '%m/%d/%y')
end

def count_reg_hours(time_array)
  time_array.reduce(Hash.new(0)) do |time_hash, time|
    time_hash[time.split(':')[0].to_sym] += 1
    time_hash
  end
end

def largest_hash(hash)
  hash.max_by{ |key, val| val }
end

def convert_to_weekday(weekday_number)
  weekdays = {
    :"0" => 'Sunday', :"1" => 'Monday', :"2" => 'Tuesday', :"3" => 'Wednesday',
    :"4" => 'Thursday', :"5" => 'Friday', :"6" => 'Saturday'
  }
  weekdays[weekday_number]
end

def count_reg_days(date_array)
  date_array.reduce(Hash.new(0)) do |day_hash, date|
    day_hash[date.wday.to_s.to_sym] += 1
    day_hash
  end
end

def track_registration(reg_date_time, reg_day_array, reg_hour_array)
  reg_date = clean_date(get_date(reg_date_time))
  reg_hour = get_time(reg_date_time)
  reg_day_array << reg_date
  reg_hour_array << reg_hour
end

def calculate_top_reg_day(reg_day_array)
  days = count_reg_days(reg_day_array)
  convert_to_weekday(largest_hash(days)[0])
end

def calculate_top_reg_hour(reg_hour_array)
  hours = count_reg_hours(reg_hour_array)
  largest_hash(hours)[0].to_s
end
  

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end


puts 'Event Manager Initialized!'

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter

reg_day_array = []
reg_hour_array = []

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  reg_date_time = row[:regdate]

  zipcode = clean_zipcode(row[:zipcode])

  phone_number = clean_phone_number(row[:homephone])
  puts 'Phone Num: ' + phone_number

  legislators = legislators_by_zipcode(zipcode)

  form_letter = erb_template.result(binding)
  
  save_thank_you_letter(id, form_letter)

  ## Track registration time/day ##
  track_registration(reg_date_time, reg_day_array, reg_hour_array)
end

top_hour = calculate_top_reg_hour(reg_hour_array)
top_day = calculate_top_reg_day(reg_day_array)

puts "Most common registration hour: #{top_hour}"
puts "Most common registration day: #{top_day}"
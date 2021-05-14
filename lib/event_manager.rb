# frozen_string_literal: true

require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'time'

def clean_zip_code(zip_code)
  zip_code.to_s.rjust(5, '0')[0..4]
end

def legislators_by_zipcode(zip_code)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    civic_info.representative_info_by_address(
      address: zip_code,
      levels: 'country',
      roles: %w[legislatorUpperBody legislatorLowerBody]
    ).officials
  rescue Google::Apis::ClientError
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def clean_phone_number(phone_number)
  phone_number = phone_number.delete '^0-9'
  length = phone_number.length

  if length == 10
    phone_number
  elsif length == 11 && phone_number[0] == '1'
    phone_number[1..10]
  else
    ''
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

puts 'EventManager Initialized!'

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter
registration_hours = []

def peak_hours(hours)
  # Create a hash that contain the instances for hours registered
  registration_hours = hours.each_with_object(Hash.new(0)) do |hour, accumulator|
    accumulator[hour.to_s.to_sym] += 1
    accumulator
  end

  max_occurrences = registration_hours.max_by { |_num, instances| instances }

  # Save only the times that ocurred most
  peak_hours = registration_hours.select { |_num, instances| instances == max_occurrences[1] }
  # Then convert them to the format 00:00
  peak_hours = peak_hours.map { |num, _instances| "#{num}:00" }

  "Peak hours are: #{peak_hours.join(' ')}"
end

contents.each do |row|
  id = row[0]
  name = row[:first_name]

  zip_code = clean_zip_code(row[:zipcode])

  legislators = legislators_by_zipcode(zip_code)

  form_letter = erb_template.result(binding)

  phone_number = clean_phone_number(row[:homephone])

  registration_hours.push(Time.strptime(row[:regdate], '%m/%d/%y %k:%M').hour)

  save_thank_you_letter(id, form_letter)
end

puts peak_hours(registration_hours)

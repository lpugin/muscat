require 'stringio'
class LogModelErrorsJob < ApplicationJob
  queue_as :default
  
  def initialize
    super
    @parallel_jobs = 10
    @all_src = Source.all.count
    @limit = @all_src / @parallel_jobs
  end
  
  def perform(*args)
    # Capture all the puts from the inner classes
    new_stdout = StringIO.new
    old_stdout = $stdout
    old_stderr = $stderr

    begin_time = Time.now
    
    String.disable_colorization true
    
    results = Parallel.map(0..@parallel_jobs, in_processes: @parallel_jobs) do |jobid|
      errors = {}
      validations = {}
      offset = @limit * jobid

      Source.order(:id).limit(@limit).offset(offset).select(:id).each do |sid|
        s = Source.find(sid.id)
        begin
          ## Capture STDOUT and STDERR
          ## Only for the marc loading!
          $stdout = new_stdout
          $stderr = new_stdout
          
          s.marc.load_source true
          
          # Set back to original
          $stdout = old_stdout
          $stderr = old_stderr
          
          res = validate_record(s)
          validations[sid.id] = res if res && !res.empty?
        rescue
          ## Exit the capture
          $stdout = old_stdout
          $stderr = old_stderr
          
          errors[sid.id] = new_stdout.string
          new_stdout.rewind
        end
        
      end
      {errors: errors, validations: validations}
    end

    # Extract and separate the errors and validations
    total_errors = {}
    total_validations = {}
    results.each do |r|
      total_errors.merge!(r[:errors])
      total_validations.merge!(r[:validations])
    end
    
    end_time = Time.now
    
    message = "Source report started at #{begin_time.to_s}, (#{end_time - begin_time} seconds run time)"
    
    HealthReport.notify("Source", message, total_errors, total_validations).deliver_now
    
  end
  
  private
  def validate_record(record)
    
    begin
      validator = MarcValidator.new(record, false)
      validator.validate
      validator.validate_dates
      validator.validate_links
      validator.validate_unknown_tags
      return validator.get_errors
    rescue Exception => e
      puts e.message
    end
    
  end
  
end

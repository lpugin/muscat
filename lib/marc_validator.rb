class MarcValidator
include ApplicationHelper

	DEBUG = false
	
  attr_accessor :rules
  def initialize(object, warnings = true)
    @validation = EditorValidation.get_default_validation(object)
    @rules = @validation.rules
    @editor_profile = EditorConfiguration.get_default_layout(object)
    #ap @rules
    @errors = {}
    @object = object
    
    ## The marc could be already resolved
    ## Make a new safe internal version
    classname = "Marc" + object.class.to_s
    dyna_marc_class = Kernel.const_get(classname)
    @marc = dyna_marc_class.new(object.marc_source)
    
    # Parse the marc but don't read the foreign
    @marc.load_source false
    # Make the unresolved version
    @unresolved_marc = @marc.deep_copy
    @unresolved_marc.root = @marc.root.deep_copy
    # Now resolve
    @marc.root.resolve_externals
    
    @show_warnings = warnings
  end

  def validate

    @rules.each do |tag, tag_rules|
      #mandatory =  tag_rules["tags"].has_value? "mandatory"
      # Mandatory tags are tags that need to be there entirely
      # In the editor leaving a tag emply will remove it
      # Some tags have to be there for some templates.
      # Extract all the pertinent mandatory tags, exluding the ones
      # not for this template
      mandatory = tag_rules["tags"].map {|st, v| st if v == "mandatory" && !is_subtag_excluded(tag, st)}.compact
      
      marc_tags = @marc.by_tags(tag)
      
      if marc_tags.count == 0
        # This tag has to be there if "mandatory"
        if mandatory.count > 0
          #@errors[tag] = "mandatory"
          add_error(tag, nil, "mandatory")
          puts "Missing #{tag}, mandatory" if DEBUG
        end
        next
      end
      
      tag_rules["tags"].each do |subtag, rule|
        
        # The validation is per subtag basis
        # THis means that a whole tag, i.e. 856
        # can be missing and validation will pass
        # For a whole tag to be there - no matter the contents
        # the "mandatory" rule above is used
        # Here we validate the contents of the tag, i.e. $a, $b etc
        # The subtags will trigger validation error if missing
        # when required
        
        if is_subtag_excluded(tag, subtag)
          puts "Skip #{tag} #{subtag} because of tag_overrides" if DEBUG
          next
        end
        
        marc_tags.each do |marc_tag|
          marc_subtag = marc_tag.fetch_first_by_tag(subtag)
          #ap marc_subtag
          
          if rule.is_a? String
            
            if rule == "required" || rule == "required, warning"
              if !marc_subtag || !marc_subtag.content
                #@errors["#{tag}#{subtag}"] = rule
                add_error(tag, subtag, rule) if (!@validation.is_warning?(tag, subtag) || @show_warnings)
                puts "Missing #{tag} #{subtag}, #{rule}" if DEBUG
              end
            elsif rule == "uniq"
              binding.pry
            else
              puts "Unknown rule #{rule}" if rule != "mandatory"
            end
            
          elsif rule.is_a? Hash
            if rule.has_key?("required_if")
              # This is another hash! gotta love json
              rule["required_if"].each do |other_tag, other_subtag|
                # Try to get this other tag first
                # the validation passes if it is not there
                other_marc_tag = @marc.first_occurance(other_tag)
                if other_marc_tag
                  other_marc_subtag = other_marc_tag.fetch_first_by_tag(other_subtag)
                  # The other subtag is there. see if we have the subtag 
                  # that is required bu the "other" one
                  if other_marc_subtag && other_marc_subtag.content
                    # if it is not here raise an error
                    if !marc_subtag || !marc_subtag.content
                      #@errors["#{tag}#{subtag}"] = "required_if-#{other_tag}#{other_subtag}"
                      add_error(tag, subtag, "required_if-#{other_tag}#{other_subtag}")
                      puts "Missing #{tag} #{subtag}, required_if-#{other_tag}#{other_subtag}" if DEBUG
                    end
                  end
                end
              end
            end
          end
        
        end
      
      end
    
    end
  
  end
  
  def validate_links
    @marc.all_tags.each do |marctag|
      
      foreigns = marctag.get_foreign_subfields
      next if foreigns.empty?
      
      master = marctag.get_master_foreign_subfield
      unresolved_tags = @unresolved_marc.by_tags_with_subtag([marctag.tag], master.tag, master.content.to_s)

      if unresolved_tags.empty?
        add_error(marctag.tag, master.tag, "foreign-tag: Searching resolved master value in unresolved marc yields no results")
        next
      end
      
      unresolved_tag = match_tags(marctag, unresolved_tags, foreigns)
      
      if !unresolved_tag
        add_error(marctag.tag, master.tag, "foreign-tag: Unable to find exach match in tags with multiple same master tags")
        next
      end

      foreigns.each do |foreign_subtag|
        next if foreign_subtag.tag == master.tag #we already got the master

        puts "more than one foreign subtag" if unresolved_tag.fetch_all_by_tag(foreign_subtag.tag).count > 1
        subtag = unresolved_tag.fetch_first_by_tag(foreign_subtag.tag) # get the first
        if subtag && subtag.content
          if subtag.content != foreign_subtag.content
            add_error(marctag.tag, foreign_subtag.tag, "foreign-tag: different unresolved value: #{subtag.content} ##{foreign_subtag.foreign_object.id}")
          end
        else
          add_error(marctag.tag, foreign_subtag.tag, "foreign-tag: tag not present in unresolved marc")
        end
      end
      
    end
  end
  
  def validate_dates
    
    @marc.each_by_tag("260") do |marctag|
      marctag.each_by_tag("c") do |marcsubtag|
        next if !marcsubtag || !marcsubtag.content
        dates = []
        dates = date_to_array(marcsubtag.content, false)
        
        next if dates.count == 0
        dates.sort!.uniq!

        max = min = dates[0].to_i
        
        if dates.count > 1
          max = dates.last.to_i
          min = dates.first.to_i
        end
        
        # Make a warning for a year n the future
        # I can be legitimate, like a forthcoming publication
        if max > Date.today.year
          add_error("260", "c", "Date in the future: #{max} (#{marcsubtag.content})")
        end
        
        # Make a warning if it is before the 11th century
        # we have sources in the 11th century
        if min < 1000
          add_error("260", "c", "Date too far in the past: #{min} (#{marcsubtag.content})")
        end
        
      end
    end
  end


  def validate_unknown_tags
    @unknown_tags = []
    #begin
      @editor_profile.each_tag_not_in_layout(@object) do |t|
        add_error(t, "unknown-tag", "Unknown tag in layout")
      end
      #rescue
    #  add_error("load", "unknown-tag", "Could not read tag layout")
    #end
  end
  
  def has_errors
    return @errors.count > 0
  end
  
  def get_errors
    @errors
  end
  
  def to_s
    output = ""
    @errors.each do |tag, subtags|
      subtags.each do |subtag, messages|
        messages.each do |message|
          output += "#{@object.id}\t#{tag}\t#{subtag}\t#{message}\n"
        end
      end
    end
    output
  end
  
  private
  
  def match_tags(marctag, unresolved_tags, foreigns)
    exclude_subfields = foreigns.collect {|s| s.tag}
    found = true
    #ap "========================="
    #ap marctag
    unresolved_tags.each do |utag|
      #ap "-----------------------"
      #ap utag
      marctag.children do |resolved_subtag|
        subtag_found = false
        # The linked subfields are analyzed afterwards
        # Here we make sure that *all* the fields match
        next if exclude_subfields.include?(resolved_subtag.tag)
        # We can have scattered subtags in random order
        # Should not happen but...
        utag.each_by_tag(resolved_subtag.tag) do |usubtag|
          subtag_found = true if usubtag.content == resolved_subtag.content
          #puts usubtag.content
          #ap resolved_subtag.content
        end
        
        found &= subtag_found
      end
      #ap found
      return utag if found
      found = true
    end
    nil
  end
  
  def add_error(tag, subtag, message)
    subtag = "tag_errors" if !subtag
    @errors[tag] = {} if !@errors.has_key?(tag)
    @errors[tag][subtag] = [] if !@errors[tag].has_key?(subtag)
    
    @errors[tag][subtag] << message
    
  end
  
  def is_subtag_excluded(tag, subtag)
        
    # Skip tags based on configuration
    # i.e. collections have different tags
    tag_overrides = @rules[tag]["tag_overrides"]
    if tag_overrides && tag_overrides["exclude"][subtag]
      if tag_overrides["exclude"][subtag].include?(@object.get_record_type.to_s)
        return true
      end
    end
    return false
  end
  
end

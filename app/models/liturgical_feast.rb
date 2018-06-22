# Describes any kind of liturgical feast (e.g. Adventus) linked wit a Source
#
# === Fields
# * <tt>name</tt> - Name of this particular feast
# * <tt>notes</tt>
# * <tt>src_count</tt> - The number of sources that reference this lib.
#
# the other standard wf_* fields are not shown.
# The class provides the same functionality as similar models, see Catalogue

class LiturgicalFeast < ApplicationRecord
  
  has_and_belongs_to_many(:referring_sources, class_name: "Source", join_table: "sources_to_liturgical_feasts")
  has_many :folder_items, as: :item, dependent: :destroy
  has_many :delayed_jobs, -> { where parent_type: "LiturgicalFeast" }, class_name: 'Delayed::Backend::ActiveRecord::Job', foreign_key: "parent_id"
  belongs_to :user, :foreign_key => "wf_owner"
    
  validates_presence_of :name
  
  validates_uniqueness_of :name
  
  #include NewIds
  
  before_destroy :check_dependencies
  
  #before_create :generate_new_id
  after_save :reindex
  
  attr_accessor :suppress_reindex_trigger

  alias_attribute :id_for_fulltext, :id 

  enum wf_stage: [ :inprogress, :published, :deleted ]
  enum wf_audit: [ :basic, :minimal, :full ]
  
  # Suppresses the solr reindex
  def suppress_reindex
    self.suppress_reindex_trigger = true
  end
  
  def reindex
    return if self.suppress_reindex_trigger == true
    self.index
  end

  searchable :auto_index => false do
    integer :id
    text :id_text do
      id_for_fulltext
    end
    string :name_order do
      name
    end
    text :name
  
    text :notes
    text :alternate_terms
    string :alternate_terms_order do
      alternate_terms
    end
		
    join(:folder_id, :target => FolderItem, :type => :integer, 
              :join => { :from => :item_id, :to => :id })
    
    integer :src_count_order, :stored => true do 
      LiturgicalFeast.count_by_sql("select count(*) from sources_to_liturgical_feasts where liturgical_feast_id = #{self[:id]}")
    end
  end

  def check_dependencies
    if (self.referring_sources.count > 0)
      errors.add :base, "The liturgical fease could not be deleted because it is used"
      return false
    end
  end
  
end

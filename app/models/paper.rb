class Paper < ActiveRecord::Base

  belongs_to  :submitting_author,
              :class_name => 'User',
              :validate => true,
              :foreign_key => "user_id"

  include AASM

  aasm :column => :state do
    state :submitted, :initial => true
    state :under_review, :before_enter => :create_review_issue
    state :review_completed
    state :superceded
    state :accepted
    state :rejected

    event :reject do
      transitions :to => :rejected
    end

    event :start_review do
      transitions :from => :submitted, :to => :under_review
    end

    event :accept do
      transitions :to => :accepted
    end
  end

  VISIBLE_STATES = [
    "accepted",
    "superceded"
  ]

  IN_PROGRESS_STATES = [
    "submitted",
    "under_review"
  ]

  default_scope  { order(:created_at => :desc) }
  scope :recent, lambda { where('created_at > ?', 1.week.ago) }
  scope :submitted, lambda { where('state = ?', 'submitted') }
  scope :in_progress, -> { where(:state => IN_PROGRESS_STATES) }
  scope :visible, -> { where(:state => VISIBLE_STATES) }
  scope :everything, lambda { where('state != ?', 'rejected') }

  before_create :set_sha

  validates_presence_of :title
  validates_presence_of :repository_url, :message => "^Repository address can't be blank"
  validates_presence_of :software_version, :message => "^Version can't be blank"
  validates_presence_of :body, :message => "^Description can't be blank"

  def self.featured
    # TODO: Make this a thing
    Paper.first
  end

  def self.popular
    recent
  end

  def to_param
    sha
  end

  def pretty_repository_name
    if repository_url.include?('github.com')
      name, owner = repository_url.scan(/(?<=github.com\/).*/i).first.split('/')
      return "#{name} / #{owner}"
    else
      return repository_url
    end
  end

  def pretty_doi
    return "" unless archive_doi

    matches = archive_doi.scan(/\b(10[.][0-9]{4,}(?:[.][0-9]+)*\/(?:(?!["&\'<>])\S)+)\b/).flatten

    if matches.any?
      return matches.first
    else
      return archive_doi
    end
  end

  # Make sure that DOIs have a full http URL
  # e.g. turn 10.6084/m9.figshare.828487 into http://dx.doi.org/10.6084/m9.figshare.828487
  def doi_with_url
    return "" unless archive_doi
    
    bare_doi = archive_doi[/\b(10[.][0-9]{4,}(?:[.][0-9]+)*\/(?:(?!["&\'<>])\S)+)\b/]

    if archive_doi.include?("http://dx.doi.org/")
      return archive_doi
    elsif bare_doi
      return "http://dx.doi.org/#{bare_doi}"
    else
      return archive_doi
    end
  end

  def create_review_issue
    return false if review_issue_id
    issue = GITHUB.create_issue("openjournals/joss-reviews",
                                "Submission: #{self.title}",
                                review_body,
                                { :labels => "review" })

    set_review_issue(issue)
  end

  def set_review_issue(issue)
    self.update_attribute(:review_issue_id, issue.number)
  end

  def update_review_issue(comment)
    GITHUB.add_comment("openjournals/joss-reviews", self.review_issue_id, comment)
  end

  def review_url
    "https://github.com/openjournals/joss-reviews/issues/#{self.review_issue_id}"
  end

  def review_body
    ActionView::Base.new(Rails.configuration.paths['app/views']).render(
      :template => 'shared/review_body', :format => :txt,
      :locals => { :paper => self }
    )
  end

  def pretty_state
    state.humanize.downcase
  end

  # Returns DOI with URL e.g. "http://dx.doi.org/10.21105/joss.00001"
  def cross_ref_doi_url
    "http://dx.doi.org/#{doi}"
  end

  def status_badge
    case self.state.to_s
    when "submitted"
      '<svg xmlns="http://www.w3.org/2000/svg" width="108" height="20"><linearGradient id="b" x2="0" y2="100%"><stop offset="0" stop-color="#bbb" stop-opacity=".1"/><stop offset="1" stop-opacity=".1"/></linearGradient><mask id="a"><rect width="108" height="20" rx="3" fill="#fff"/></mask><g mask="url(#a)"><path fill="#555" d="M0 0h40v20H0z"/><path fill="#007ec6" d="M40 0h68v20H40z"/><path fill="url(#b)" d="M0 0h108v20H0z"/></g><g fill="#fff" text-anchor="middle" font-family="DejaVu Sans,Verdana,Geneva,sans-serif" font-size="11"><text x="20" y="15" fill="#010101" fill-opacity=".3">JOSS</text><text x="20" y="14">JOSS</text><text x="73" y="15" fill="#010101" fill-opacity=".3">Submitted</text><text x="73" y="14">Submitted</text></g></svg>'
    when "under_review"
      '<svg xmlns="http://www.w3.org/2000/svg" width="129" height="20"><linearGradient id="b" x2="0" y2="100%"><stop offset="0" stop-color="#bbb" stop-opacity=".1"/><stop offset="1" stop-opacity=".1"/></linearGradient><mask id="a"><rect width="129" height="20" rx="3" fill="#fff"/></mask><g mask="url(#a)"><path fill="#555" d="M0 0h40v20H0z"/><path fill="#dfb317" d="M40 0h89v20H40z"/><path fill="url(#b)" d="M0 0h129v20H0z"/></g><g fill="#fff" text-anchor="middle" font-family="DejaVu Sans,Verdana,Geneva,sans-serif" font-size="11"><text x="20" y="15" fill="#010101" fill-opacity=".3">JOSS</text><text x="20" y="14">JOSS</text><text x="83.5" y="15" fill="#010101" fill-opacity=".3">Under Review</text><text x="83.5" y="14">Under Review</text></g></svg>'
    when "review_completed"
      '<svg xmlns="http://www.w3.org/2000/svg" width="150" height="20"><linearGradient id="b" x2="0" y2="100%"><stop offset="0" stop-color="#bbb" stop-opacity=".1"/><stop offset="1" stop-opacity=".1"/></linearGradient><mask id="a"><rect width="150" height="20" rx="3" fill="#fff"/></mask><g mask="url(#a)"><path fill="#555" d="M0 0h40v20H0z"/><path fill="#dfb317" d="M40 0h110v20H40z"/><path fill="url(#b)" d="M0 0h150v20H0z"/></g><g fill="#fff" text-anchor="middle" font-family="DejaVu Sans,Verdana,Geneva,sans-serif" font-size="11"><text x="20" y="15" fill="#010101" fill-opacity=".3">JOSS</text><text x="20" y="14">JOSS</text><text x="94" y="15" fill="#010101" fill-opacity=".3">Review Complete</text><text x="94" y="14">Review Complete</text></g></svg>'
    when "accepted"
      "<svg xmlns='http://www.w3.org/2000/svg' width='168' height='20'><linearGradient id='b' x2='0' y2='100%'><stop offset='0' stop-color='#bbb' stop-opacity='.1'/><stop offset='1' stop-opacity='.1'/></linearGradient><mask id='a'><rect width='168' height='20' rx='3' fill='#fff'/></mask><g mask='url(#a)'><path fill='#555' d='M0 0h39v20H0z'/><path fill='#4c1' d='M39 0h129v20H39z'/><path fill='url(#b)' d='M0 0h168v20H0z'/></g><g fill='#fff' text-anchor='middle' font-family='DejaVu Sans,Verdana,Geneva,sans-serif' font-size='11'><text x='19.5' y='15' fill='#010101' fill-opacity='.3'>JOSS</text><text x='19.5' y='14'>JOSS</text><text x='102.5' y='15' fill='#010101' fill-opacity='.3'>#{self.doi}</text><text x='102.5' y='14'>#{self.doi}</text></g></svg>"
    when "rejected"
      '<svg xmlns="http://www.w3.org/2000/svg" width="100" height="20"><linearGradient id="b" x2="0" y2="100%"><stop offset="0" stop-color="#bbb" stop-opacity=".1"/><stop offset="1" stop-opacity=".1"/></linearGradient><mask id="a"><rect width="100" height="20" rx="3" fill="#fff"/></mask><g mask="url(#a)"><path fill="#555" d="M0 0h40v20H0z"/><path fill="#e05d44" d="M40 0h60v20H40z"/><path fill="url(#b)" d="M0 0h100v20H0z"/></g><g fill="#fff" text-anchor="middle" font-family="DejaVu Sans,Verdana,Geneva,sans-serif" font-size="11"><text x="20" y="15" fill="#010101" fill-opacity=".3">JOSS</text><text x="20" y="14">JOSS</text><text x="69" y="15" fill="#010101" fill-opacity=".3">Rejected</text><text x="69" y="14">Rejected</text></g></svg>'
    else
      '<svg xmlns="http://www.w3.org/2000/svg" width="102" height="20"><linearGradient id="b" x2="0" y2="100%"><stop offset="0" stop-color="#bbb" stop-opacity=".1"/><stop offset="1" stop-opacity=".1"/></linearGradient><mask id="a"><rect width="102" height="20" rx="3" fill="#fff"/></mask><g mask="url(#a)"><path fill="#555" d="M0 0h40v20H0z"/><path fill="#9f9f9f" d="M40 0h62v20H40z"/><path fill="url(#b)" d="M0 0h102v20H0z"/></g><g fill="#fff" text-anchor="middle" font-family="DejaVu Sans,Verdana,Geneva,sans-serif" font-size="11"><text x="20" y="15" fill="#010101" fill-opacity=".3">JOSS</text><text x="20" y="14">JOSS</text><text x="70" y="15" fill="#010101" fill-opacity=".3">Unknown</text><text x="70" y="14">Unknown</text></g></svg>'
    end
  end

private

  def set_sha
    self.sha = SecureRandom.hex
  end
end

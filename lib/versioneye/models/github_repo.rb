class GithubRepo < Versioneye::Model

  include Mongoid::Document

  field :github_id   , type: String
  field :name        , type: String
  field :fullname    , type: String
  field :user_login  , type: String
  field :owner_login , type: String
  field :owner_type  , type: String
  field :owner_avatar, type: String
  field :language    , type: String
  field :description , type: String
  field :private     , type: Boolean, default: false
  field :fork        , type: Boolean, default: false
  field :github_url  , type: String
  field :homepage    , type: String
  field :git_url     , type: String
  field :html_url    , type: String
  field :forks       , type: Integer
  field :watchers    , type: Integer
  field :size        , type: Integer
  field :etag        , type: String
  field :branches    , type: Array
  field :project_files, type: Hash,    :default => nil
  field :created_at  , type: DateTime, :default => DateTime.now
  field :updated_at  , type: DateTime, :default => DateTime.now #when github repo was updated
  field :pushed_at   , type: DateTime, :default => DateTime.now
  field :cached_at   , type: DateTime, :default => DateTime.now

  belongs_to :user

  index({ user_id: 1 },     { name: "user_id_index"    , background: true })
  index({ name: 1 },        { name: "name_index"       , background: true })
  index({ fullname: 1 },    { name: "fullname_index"   , background: true })
  index({ language: 1 },    { name: "language_index"   , background: true })
  index({ owner_login: 1 }, { name: "owner_login_index", background: true })
  index({ owner_type: 1 },  { name: "owner_type_index" , background: true })
  index({ owner_login: 1, owner_type: 1 }, { name: "login_typ_index", background: true })
  index({ github_id: 1, fullname: 1 },     { name: "githubid_fullname_index", background: true })

  scope :by_language   , ->(lang){where(language: lang)}
  scope :by_user       , ->(user){where(user_id: user._id)}
  scope :by_owner_login, ->(login){where(owner_login: login)}
  scope :by_fullname   , ->(fullname){where(fullname: fullname)}
  scope :by_owner_type , ->(type_name){where(owner_type: type_name)}
  scope :by_org        , ->(org_name){where(owner_login: org_name, owner_type: 'organization')}


  def self.get_owner_type(user, owner_info)
    owner_type = "unknown"
    user_login = github_login_for user

    case owner_info[:type].to_s.downcase
    when 'organization'
      owner_type = 'organization'
    when 'user'
      if user_login != owner_info[:login] then
        owner_type = 'team'
      else
        owner_type = 'user'
      end
    else
      owner_type = 'unknown'
    end

    owner_type
  end


  def self.github_login_for user
    if user[:github_login].nil?
      user_info = Github.user(user.github_token)
      if user_info
        user[:github_login] = user_info[:login]
        user.save
      end
    end
    user[:github_login]
  rescue => e
    log.error e.message
    log.error e.backtrace.join("\n")
    nil
  end

  # This dataset is incomplete. It will be completed by github_repo_import_worker
  def self.build_or_update user, repo_data, etag = nil
    return nil if repo_data.nil? || repo_data.empty?

    repo_data = repo_data.deep_symbolize_keys

    owner_info = repo_data[:owner]
    owner_type = get_owner_type(user, owner_info)

    repo = GithubRepo.find_or_create_by(:github_id => user.github_id, :fullname => repo_data[:full_name])
    repo.update_attributes!({
      user_id: user.id,
      user_login: user[:user_login],
      name: repo_data[:name],
      fullname: repo_data[:full_name],
      owner_login: owner_info[:login],
      owner_avatar: owner_info[:avatar_url],
      owner_type: owner_type,
      language: repo_data[:language].to_s.downcase,
      description: repo_data[:description],
      private: repo_data[:private],
      fork: repo_data[:fork],
      github_url: repo_data[:url],
      homepage: repo_data[:homepage],
      git_url: repo_data[:git_url],
      html_url: repo_data[:html_url],
      forks: repo_data[:forks],
      watchers: repo_data[:watchers],
      size: repo_data[:size],
      etag: etag.to_s,
      created_at: repo_data[:created_at],
      updated_at: repo_data[:updated_at],
      pushed_at: repo_data[:pushed_at]

      # This will be completed by github_repo_import_worker or have to be set from extern.
      # branches: repo_data[:branches],
      # project_files: repo_data[:project_files],
    })
    repo
  rescue => e
    log.error e.message
    log.error e.backtrace.join("\n")
    nil
  end

end

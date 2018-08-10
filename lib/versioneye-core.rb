require 'mongoid'
require 'tire'
require 'dalli'
require 'httparty'
require 'action_mailer'
require 'stripe'

require 'settings'
require 'versioneye/model'
require 'versioneye/service'

class VersioneyeCore


  def initialize
    puts "start initialize versioneye-core"
    init_etcd
    init_logger
    init_mongodb
    init_settings
    init_elastic_search
    init_memcached
    init_email
    init_stripe
    init_s3
    init_values
    set_ssl_options
    puts "end initialize versioneye-core"
  end


  def set_ssl_options
    env        = Settings.instance.environment
    ssl_verify = GlobalSetting.get( env, 'ssl_verify' )
    if ssl_verify.to_s.eql?('false')
      Octokit.connection_options[:ssl] = { :verify => false }
      HTTParty::Basement.default_options.update(verify: false)
    else
      Octokit.connection_options[:ssl] = { :verify => true }
      HTTParty::Basement.default_options.update(verify: true)
    end
  rescue => e
    log.error e.message
    log.error e.backtrace.join("\n")
  end


  def init_values
    user_count = User.count
    return nil if user_count.to_i > 0

    puts "START to create indexes"
    Indexer.create_indexes

    puts "START to create default admin"
    AdminService.create_default_admin

    puts "START to create default plans"
    Plan.create_defaults

    puts "START to create ES Product index"
    EsProduct.reset

    puts "START to fill MavenRepository"
    MavenRepository.fill_it

    puts "START to import spdx licenses"
    LicenseService.import_from "/app/data/spdx_license.csv"

    GlobalSetting.set( 'enterprise', 'sync_db', '17 2 * * *' )
    puts "---"
  rescue => e
    log.error e.message
    log.error e.backtrace.join("\n")
  end


  def init_mongodb
    puts " - initialize MongoDB (old) for #{Settings.instance.environment}. DB_PORT_27017_TCP_ADDR: #{ENV['DB_PORT_27017_TCP_ADDR']}:#{ENV['DB_PORT_27017_TCP_PORT']}."
    puts " - initialize MongoDB for #{Settings.instance.environment}. DB_URI: #{ENV['DB_URI']}:#{ENV['DB_PORT']}"
    Mongoid.load!("config/mongoid.yml", Settings.instance.environment)
    #Mongoid.logger.level = Logger::INFO
    Mongo::Logger.logger.level = Logger::ERROR
  rescue => e
    log.error e.message
    log.error e.backtrace.join("\n")
  end

  def init_email
    puts " - initialize email settings"
    ActionMailer::Base.raise_delivery_errors = true
    ActionMailer::Base.delivery_method = :smtp
    ActionMailer::Base.view_paths = File.expand_path('../versioneye/views/', __FILE__)
    EmailSettingService.update_action_mailer_from_db
  rescue => e
    log.error e.message
    log.error e.backtrace.join("\n")
  end

  def init_stripe
    puts " - initialize Stripe"
    env = Settings.instance.environment
    return nil if env.to_s.eql?("enterprise")

    Stripe.api_key = Settings.instance.stripe_secret_key
  rescue => e
    log.error e.message
    log.error e.backtrace.join("\n")
  end

  def init_s3
    puts " - initialize Amazon S3"
    env = Settings.instance.environment
    return nil if env.to_s.eql?("enterprise")

    S3.set_aws_crendentials
  rescue => e
    log.error e.message
    log.error e.backtrace.join("\n")
  end

  def init_logger
    puts " - initialize Logger"
    Versioneye::Log.instance.log
  end

  def init_elastic_search
    es_url = 'localhost:9200'
    if !Settings.instance.elasticsearch_addr.to_s.empty? && !Settings.instance.elasticsearch_port.to_s.empty?
      es_url = "#{Settings.instance.elasticsearch_addr}:#{Settings.instance.elasticsearch_port}"
    end
    puts " - initialize ElasticSearch with #{es_url} for env: #{Settings.instance.environment}"
    Tire.configure do
      url es_url
    end
  rescue => e
    log.error e.message
    log.error e.backtrace.join("\n")
  end

  def init_settings
    puts " - reload Settings from DB!"
    Settings.instance.reload_from_db GlobalSetting.new
  rescue => e
    log.error e.message
    log.error e.backtrace.join("\n")
  end

  def init_memcached
    puts " - initialize init_memcached!"
    Versioneye::Cache.instance.mc
  rescue => e
    log.error e.message
    log.error e.backtrace.join("\n")
  end

  def init_etcd
    puts " - initialize Etcd!"
    Versioneye::EtcdClient.instance.etcd
    Versioneye::EtcdClient.instance.setBackendEnvs
    Settings.instance.load_settings
  rescue => e
    log.error e.message
    log.error e.backtrace.join("\n")
  end

  private

    def log
      Versioneye::Log.instance.log
    end

end

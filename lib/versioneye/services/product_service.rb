class ProductService < Versioneye::Service


  # Languages have to be an array of strings.
  def self.search(q, group_id = nil, languages = nil, page_count = 1)
    ## No elastic search!!
    env = Settings.instance.environment
    # if !env.to_s.eql?("enterprise")
    return MongoProduct.find_by(q, '', group_id, languages, 300)
    # else
    #  return EsProduct.search(q, group_id, languages, page_count)
    # end
  rescue => e
    log.error e.message
    log.error e.backtrace.join("\n")
    MongoProduct.find_by(q, '', group_id, languages, 300)
  end


  # This method fetches and product and initializes it for the UI.
  def self.fetch_product( lang, prod_key, version = nil )
    product = Product.fetch_product lang, prod_key
    if product.nil? && lang.eql?( Product::A_LANGUAGE_CLOJURE )
      product = Product.fetch_product Product::A_LANGUAGE_JAVA, prod_key
    end
    return nil if product.nil?

    product.check_nil_version
    product.version_newest = product.version
    product.version = version if version
    product.project_usage = ReferenceService.project_references( lang, prod_key ).count

    product.all_dependencies().any_of({:parsed_version => nil}, {:current_version => nil}).each do |dep|
      DependencyService.update_parsed_version dep, dep.product
      DependencyService.outdated? dep, true
    end

    product
  end


  def self.follow language, prod_key, user
    result = false
    product = Product.fetch_product language, prod_key
    product.users = Array.new if product && product.users.nil?
    if product && user && !product.users.include?( user )
      product.users.push user
      product.followers = 0 if product.followers.nil?
      product.followers += 1
      result = product.save
      user.products.push product
      user.save
    end
    result
  rescue => e
    log.error e.message
    log.error e.backtrace.join("\n")
    false
  end


  def self.unfollow language, prod_key, user
    result = false
    product = Product.fetch_product language, prod_key
    product.users = Array.new if product && product.users.nil?
    if product && user && product.users.include?( user )
      product.users.delete(user)
      product.followers = 0 if product.followers.nil?
      product.followers -= 1
      result = product.save
      user.products.delete product
      user.save
    end
    result
  rescue => e
    log.error e.message
    log.error e.backtrace.join("\n")
    false
  end


  def self.all_products_paged
    count = Product.count()
    page = 100
    iterations = count / page
    iterations += 1
    (0..iterations).each do |i|
      skip = i * page
      products = Product.all().skip(skip).limit(page)

      yield products

      co = i * page
      log.info "all_products_paged iteration: #{i} - products processed: #{co}"
    end
  rescue => e
    log.error e.message
    log.error e.backtrace.join("\n")
  end


  def self.all_products_by_lang_paged(language)
    count = Product.where(:language => language).count()
    page = 100
    iterations = count / page
    iterations += 1
    (0..iterations).each do |i|
      skip = i * page
      products = Product.where(:language => language).all().skip(skip).limit(page)

      yield products

      co = i * page
      log.info "all_products_paged iteration: #{i} - products processed: #{co}"
    end
  rescue => e
    log.error e.message
    log.error e.backtrace.join("\n")
  end


  def self.update_meta_data_global
    all_products_paged do |products|
      log.info " - update_meta_data_global - "
      update_products products
    end
  end


  def self.update_products products
    products.each do |product|
      self.update_meta_data product, false
    end
  rescue => e
    log.error e.message
    log.error e.backtrace.join("\n")
  end


  def self.update_meta_data product, update_used_by = true
    self.update_version_data  product, false
    if update_used_by == true
      self.update_used_by_count product, true
    end
    self.update_average_release_time product
    self.update_followers_for product
    product.save
  rescue => e
    log.error e.message
    log.error e.backtrace.join("\n")
  end


  # Updates product.version with the newest version number from product.versions
  def self.update_version_data( product, persist = true )
    return nil if product.nil?

    versions = product.versions
    return nil if versions.nil? || versions.empty?

    if product.dist_tags_latest
      product.version = product.dist_tags_latest
    else
      newest_stable_version = VersionService.newest_version( versions )
      product.version = newest_stable_version.to_s
    end

    product.save if persist
  rescue => e
    log.error e.message
    log.error e.backtrace.join("\n")
  end

  def self.update_newest_version product
    self.update_version_data product
  end


  def self.update_used_by_count product, persist = true
    prod_keys = nil
    if product.group_id && product.artifact_id
      prod_keys = Dependency.where(:group_id => product.group_id, :artifact_id => product.artifact_id).distinct(:prod_key)
    else
      prod_keys = Dependency.where(:language => product.language, :dep_prod_key => product.prod_key).distinct(:prod_key)
    end

    count = prod_keys.count
    return nil if count == product.used_by_count

    prod_keys_sorted = []
    Product.where(:prod_key.in => prod_keys).desc(:used_by_count).each do |prod|
      prod_keys_sorted << prod.prod_key if !prod_keys_sorted.include?( prod.prod_key )
    end

    reference = Reference.find_or_create_by(:language => product.language, :prod_key => product.prod_key )
    reference.update_from prod_keys_sorted
    if product.group_id && product.artifact_id
      reference.group_id = product.group_id
      reference.artifact_id = product.artifact_id
    end
    reference.save

    product.used_by_count = prod_keys_sorted.count
    product.save if persist
  rescue => e
    log.error e.message
    log.error e.backtrace.join("\n")
    false
  end


  def self.update_average_release_time product
    average_release_time = VersionService.average_release_time( product.versions )
    if average_release_time.nil?
      average_release_time = VersionService.estimated_average_release_time( product.versions )
    end
    product.average_release_time = average_release_time
    average_release_time
  end


  def self.update_followers_for product
    return nil if product.followers == product.user_ids.count

    product.followers = product.user_ids.count
    product.save
  end


  def self.update_followers
    products = Product.where( :'user_ids.0' => {'$exists' => true} )
    products.each do |product|
      self.update_followers_for product
    end
  end


  def self.remove product
    EsProduct.remove( product )

    archives = Versionarchive.where( :language => product.language, :prod_key => product.prod_key )
    if archives && !archives.empty?
      archives.each do |archive|
        archive.delete
      end
    end

    links = Versionlink.where( :language => product.language, :prod_key => product.prod_key )
    if links && !links.empty?
      links.each do |link|
        link.delete
      end
    end

    dependencies = Dependency.where( :language => product.language, :prod_key => product.prod_key )
    if dependencies && !dependencies.empty?
      dependencies.each do |dependency|
        dependency.delete
      end
    end

    product.remove
  end


  def self.most_referenced(language, page)
    Product.by_language( language ).desc(:used_by_count).paginate(:page => page)
  end


  def self.count_licenses( language )
    ha = {}
    count = 0
    Product.where(:language => language).each do |prod|
      licenses = prod.license_info
      if licenses.to_s.empty? || licenses.to_s.eql?('unknown') || licenses.to_s.eql?('N/A')
        ha['unknown'] = ha['unknown'].to_i + 1
      elsif licenses.match(/Apache/i)
        ha['Apache'] = ha['Apache'].to_i + 1
      elsif licenses.match(/BSD/i)
        ha['BSD'] = ha['BSD'].to_i + 1
      elsif licenses.match(/LGPL/i)
        ha['LGPL'] = ha['LGPL'].to_i + 1
      elsif licenses.match(/AGPL/i)
        ha['AGPL'] = ha['AGPL'].to_i + 1
      elsif licenses.match(/GPL/i)
        ha['GPL'] = ha['GPL'].to_i + 1
      elsif licenses.match(/mit/i)
        ha['MIT'] = ha['MIT'].to_i + 1
      end
      count += 1
      p "#{count} - #{ha}"
    end
    ha
  end


end

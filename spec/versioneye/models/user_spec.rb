require 'spec_helper'

describe User do

  let(:github_user) { FactoryGirl.create(:github_user)}
  let(:bitbucket_user) { FactoryGirl.create(:bitbucket_user)}

  before(:each) do
    User.destroy_all
    UserFactory.create_defaults
  end

  describe "to_param" do
    it "returns username as default param" do
      github_user.username = "hanstanz"
      github_user.to_param.should eq('hanstanz')
    end
  end

  describe "create_verification" do
    it "generates a verification string" do
      github_user.verification.should be_nil
      github_user.create_verification
      github_user.verification.should_not be_nil
    end
  end

  describe 'github_account_connected' do
    it 'is connected' do
      github_user.github_id = "asgas"
      github_user.github_token = 'asgasgaga'
      github_user.github_account_connected?().should be_truthy
    end
    it 'is not connected' do
      github_user.github_id = nil
      github_user.github_token = nil
      github_user.github_account_connected?().should be_falsey
    end
  end

  describe 'bitbucket_account_connected' do
    it 'is connected' do
      github_user.bitbucket_id = "asgas"
      github_user.bitbucket_token = 'asgasgaga'
      github_user.bitbucket_account_connected?().should be_truthy
    end
    it 'is not connected' do
      github_user.bitbucket_id = nil
      github_user.bitbucket_token = nil
      github_user.bitbucket_account_connected?().should be_falsey
    end
  end

  describe 'find_all' do
    it 'finds something' do
      User.destroy_all
      User.send  :include, WillPaginateMongoid::MongoidPaginator
      user_1 = UserFactory.create_new 1, true
      user_2 = UserFactory.create_new 2, true
      user_3 = UserFactory.create_new 3, true
      users = User.find_all(1)
      users.count.should == 3
    end
  end

  describe "activate!" do
    it "does not activate because of false input" do
      User.activate!(nil).should be_falsey
      User.activate!('').should be_falsey
      User.activate!('asgasgasga').should be_falsey
    end
    it "activates a user" do
      github_user.create_verification
      github_user.save
      verification = github_user.verification
      verification.should_not be_nil
      verification.size.should be > 2
      User.activate!(verification)
      user = User.find(github_user.id)
      user.should_not be_nil
      user.verification.should be_nil
    end
  end

  describe "activated?" do
    it "tests the activated? method" do
      github_user.create_verification
      github_user.verification.should_not be_nil
      github_user.activated?.should be_falsey
      github_user.verification = nil
      github_user.activated?.should be_truthy
    end
  end

  describe "activate!" do
    it "tests the activated? method" do
      email = "hans1@tanz.de"
      github_user.fullname = "Hans1 Tanz"
      github_user.username = "hanstanz1"
      github_user.email = email
      github_user.password = "password"
      github_user.salt = "salt"
      github_user.create_verification
      github_user.save

      db_user = User.find_by_email( email )
      db_user.should_not be_nil
      db_user.verification.should_not be_nil
      db_user.activated?.should be_falsey
      User.activate!(github_user.verification)

      db_user2 = User.find_by_email( email )
      db_user2.verification.should be_nil
      db_user2.activated?.should be_truthy
    end
  end

  describe "save" do
    it "saves a new user in the db" do
      User.delete_all
      email = "h+ans2@tanz.de"
      user = User.new
      user.fullname = "Hans Tanz"
      user.username = "hanstanz2"
      user.email = email
      user.password = "password"
      user.salt = "salt"
      user.terms = true
      user.datenerhebung = true
      user.save.should be_truthy
      db_user = User.find_by_email( email )
      db_user.should_not be_nil
      user.remove
    end
    it "saves a new user in the db" do
      User.delete_all
      email = "daniele.sluijters+versioneye@gmail.com"
      user = User.new
      user.fullname = "Daniele sluijters"
      user.username = "sluijters"
      user.email = email
      user.password = "password"
      user.salt = "salt"
      user.terms = true
      user.datenerhebung = true
      user.save.should be_truthy
      db_user = User.find_by_email( email )
      db_user.should_not be_nil
      user.remove
    end
    it "do not save because terms are not accepted" do
      User.delete_all
      email = "daniele.sluijters+versioneye@gmail.com"
      user = User.new
      user.fullname = "Daniele sluijters"
      user.username = "sluijters"
      user.email = email
      user.password = "password"
      user.salt = "salt"
      user.terms = false
      user.datenerhebung = true
      user.save.should be_falsey
      User.count.should == 0
      user.remove
    end
    it "test case for tobias" do
      User.delete_all
      email = "t@blinki.st"
      user = User.new
      user.fullname = "Tobias"
      user.username = "blinki"
      user.email = email
      user.password = "password"
      user.salt = "salt"
      user.terms = true
      user.datenerhebung = true
      user.save
      db_user = User.find_by_email( email )
      db_user.should_not be_nil
      db_user.remove
    end
    it "dosn't save. Because email is wrong" do
      User.delete_all
      email = "h+ans+2@ta+nzde"
      user = User.new
      user.fullname = "Hans Tanz"
      user.username = "hanstanz"
      user.email = email
      user.password = "password"
      user.salt = "salt"
      user.terms = true
      user.datenerhebung = true
      user.save.should be_falsey
      db_user = User.find_by_email( email )
      db_user.should be_nil
      user.remove
    end
    it "dosn't save. Because email is unique" do
      User.delete_all
      github_user
      email = "hans@tanz.de"
      user = User.new
      user.fullname = "Hans Tanz"
      user.username = "hanstanz55"
      user.email = email
      user.password = "password"
      user.salt = "salt"
      user.terms = true
      user.datenerhebung = true
      user.save.should be_falsey
      user.remove
    end
    it "dosn't save. Because email is not valid" do
      User.delete_all
      email = "hans@tanz"
      user = User.new
      user.fullname = "Hans Tanz"
      user.username = "hanstanz5gasg"
      user.email = email
      user.password = "password"
      user.salt = "salt"
      user.terms = true
      user.datenerhebung = true
      save = user.save
      save.should be_falsey
      db_user = User.find_by_email( email )
      db_user.should be_nil
      user.remove
    end
  end

  describe "has_password?" do
    it "doesn't have the password" do
      github_user.has_password?("agfasgasfgasfg").should be_falsey
    end
    it "does have the password" do
      github_user.has_password?("password").should be_truthy
    end
  end

  describe "find_by_email" do
    it "returns nil for nil" do
      User.find_by_email(nil).should be_nil
    end
    it "returns nil for empty string" do
      User.find_by_email("   ").should be_nil
    end
    it "doesn't find by email" do
      User.find_by_email("agfasgasfgasfg").should be_nil
    end
    it "does find by email" do
      github_user
      user = User.find_by_email("hans@tanz.de")
      user.should_not be_nil
      user.email.eql?(github_user.email).should be_truthy
      user.id.eql?(github_user.id).should be_truthy
    end
  end

  describe "find_by_username" do
    it "doesn't find by username" do
      User.find_by_username("agfasgasfgasfg").should be_nil
    end
    it "does find by username" do
      github_user
      user = User.find_by_username("hans_tanz")
      user.should_not be_nil
      user.username.eql?(github_user.username).should be_truthy
      user.id.eql?(github_user.id).should be_truthy
    end
  end

  describe "find_by_github_id" do
    it "doesn't find by github id" do
      User.find_by_github_id("agfgasasgasfgasfg").should be_nil
    end
    it "returns nil for nil" do
      User.find_by_github_id( nil ).should be_nil
    end
    it "returns nil for empty string" do
      User.find_by_github_id( "   " ).should be_nil
    end
    it "does find by github_id" do
      github_user
      user = User.find_by_github_id("github_id_123")
      user.should_not be_nil
      user.github_id.eql?(github_user.github_id).should be_truthy
      user.id.eql?(github_user.id).should be_truthy
    end
  end

  describe "find_by_bitbucket_id" do
    it "doesn't find by bitbucket id" do
      User.find_by_bitbucket_id("agfgasasgasfgasfg").should be_nil
    end
    it "returns nil for nil" do
      User.find_by_bitbucket_id( nil ).should be_nil
    end
    it "returns nil for empty string" do
      User.find_by_bitbucket_id( "   " ).should be_nil
    end
    it "does find by bitbucket_id" do
      bitbucket_user
      user = User.find_by_bitbucket_id("versioneye_test")
      user.should_not be_nil
      user.bitbucket_id.eql?(bitbucket_user.bitbucket_id).should be_truthy
      user.id.eql?(bitbucket_user.id).should be_truthy
    end
  end

  describe "authenticate" do
    it "doesn't authenticate" do
      User.authenticate("agfasgasfgasfg", "agsasf").should be_nil
    end
    it "does authenticate" do
      github_user
      user = User.authenticate("hans@tanz.de", "password")
      user.should_not be_nil
      user.id.eql?(github_user.id).should be_truthy
    end
  end

  describe "authenticate_with_salt" do
    it "doesn't authenticate" do
      User.authenticate_with_salt(33333, "agsasf").should be_nil
    end
    it "does authenticate" do
      user = User.authenticate_with_salt(github_user.id, github_user.salt)
      user.should_not be_nil
      user.id.eql?(github_user.id).should be_truthy
    end
  end

  describe 'authenticate_with_apikey' do
    it 'auths' do
      user = UserFactory.create_new 456
      user.save.should be_truthy
      api = Api.create_new user
      api.save.should be_truthy
      us = User.authenticate_with_apikey api.api_key
      us.should_not be_nil
      us.id.to_s.should eq(user.id.to_s)
    end
  end

  describe "username_valid?" do
    it "is not" do
      User.username_valid?("agsasf").should be_truthy
    end
    it "is" do
      User.username_valid?(github_user.username).should be_falsey
    end
  end

  describe "email_valid?" do
    it "is not" do
      User.email_valid?("agsasf").should be_truthy
    end
    it "is not because it is in email_user" do
      user_email = UserEmail.new
      user_email.email = "tada@hoplaho.de"
      user_email.user_id = github_user.id.to_s
      user_email.save
      User.email_valid?(user_email.email).should be_falsey
      user_email.remove
    end
    it "is" do
      User.email_valid?(github_user.email).should be_falsey
    end
  end

  describe "update_password" do
    it "does not update the password" do
      github_user.update_password("passwordasg", "asgasgfs").should be_falsey
    end
    it "does update the password" do
      UserService.reset_password( github_user )
      github_user.update_password(github_user.verification, "newpassword").should be_truthy
      user = User.authenticate(github_user.email, "newpassword")
      user.should_not be_nil
    end
  end

  describe "password_valid" do
    it "is not valid" do
      github_user.password_valid?("passwordasgfa").should be_falsey
    end
    it "does update the password" do
      UserService.reset_password( github_user )
      github_user.update_password(github_user.verification, "newpassword").should be_truthy
      github_user.password_valid?("newpassword").should be_truthy
    end
  end

  describe "create_username" do

    it "does create a username" do
      github_user.fullname = "Robert Reiz"
      github_user.create_username
      github_user.username.should eql("RobertReiz")
    end

    it "does create a username and replace -" do
      github_user.fullname = "Hans -Reiz"
      github_user.create_username
      github_user.username.should eql("HansReiz")
    end

    it "does create a username with a randomValue" do
      github_user.fullname = "Robert Reiz"
      github_user.create_username
      github_user.username.should eql("RobertReiz")
      github_user.save

      user = User.new
      user.fullname = "Robert Reiz"
      user.create_username
      user.username.size.should > 12
    end

  end

  describe "non_followers" do
    it "returns same number of user when users follow nothing" do
      User.non_followers.count.should eql(User.all.count)
    end
    it "returns one user less, when one user starts following new Project" do
      user = User.all.first
      prod = ProductFactory.create_new
      user.products.push prod
      User.non_followers.count.should eql(User.all.count - 1)

      user[:product_ids] = Array.new
      user.save
      User.non_followers.count.should eql(User.all.count)

      user[:product_ids] = nil
      user.save
      User.non_followers.count.should eql(User.all.count)
    end
  end

  describe "follows_least" do
    it "returns nothing, when there's no user with specified number follows" do
      User.follows_least(1).count.should eql(0)
    end

    it "returns only 1 user, who follows least n packages" do
      user = User.all.first
      prod = ProductFactory.create_new
      user.products.push prod
      User.follows_least(1).count.should eql(1)
    end
  end

  describe "follows_max" do
    it "returns all users, when n is large enough" do
      User.follows_max(32768).count.should eql(User.all.count)
    end

    it "returns one user less, when one of un-followers starts following new package" do
      user = User.all.first
      prod = ProductFactory.create_new
      user.products.push prod
      User.follows_max(1).count.should eql(User.all.count - 1)
    end
  end

end

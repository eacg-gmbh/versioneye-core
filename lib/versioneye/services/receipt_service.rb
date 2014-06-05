class ReceiptService < Versioneye::Service

  require 'pdfkit'

  def self.process_receipts
    count = User.where(:plan_id.ne => nil).count
    return nil if count == 0

    per_page = 50
    skip = 0
    iterations = count / per_page
    iterations += 1

    (0..iterations).each do
      users = User.where(:plan_id.ne => nil).skip(skip).limit(per_page)
      handle_users( users )
      skip += per_page
    end
  end


  def self.handle_users( users )
    return nil if users.nil? || users.empty?

    users.each do |user|
      next if user.nil?
      next if user.plan.name_id.eql?(Plan::A_PLAN_TRIAL_0)
      next if user.stripe_token.to_s.empty?
      next if user.stripe_customer_id.to_s.empty?

      handle_user( user )
    end
  end


  def self.handle_user( user )
    customer = StripeService.fetch_customer user.stripe_customer_id
    invoices = customer.invoices
    return nil if invoices.nil? || invoices.count == 0

    invoices.each do |invoice|
      handle_invoice user, invoice
    end
  end


  def self.handle_invoice user, invoice
    invoice_id = invoice[:id]
    receipt = Receipt.where(:invoice_id => invoice_id).shift
    return nil if !receipt.nil?

    receipt = new_receipt user, invoice
    html = compile_html_invoice receipt
    compile_pdf_invoice html

    receipt
  end


  def self.new_receipt user, invoice
    receipt = Receipt.new
    receipt.update_from_billing_address user.billing_address
    receipt.update_from_invoice invoice
    receipt.receipt_nr = next_receipt_nr
    receipt.user = user
    receipt
  end


  def self.next_receipt_nr
    nr = Receipt.max(:receipt_nr)
    nr = 1000 if nr.nil?
    nr += 1
    nr
  end


  def self.compile_html_invoice receipt
    content = 'lib/versioneye/views/receipt/receipt.html.erb'
    erb = ERB.new(File.read(content))
    erb.result(receipt.get_binding)
  end


  def self.compile_pdf_invoice html
    footer  = 'lib/versioneye/views/receipt/footer.html'
    kit = PDFKit.new(html, :footer_html => footer, :page_size => 'Letter')
    file = kit.to_file('/Users/robertreiz/invoice.pdf')
  end


  # create receipt object
  # compile_html_invoice
  # compile_pdf_invoice
  # upload pdf to s3
  # persist receipt in db
  # send out email with pdf receipt attachement


end

class Import

  attr_accessor :report_name, :list_id, :csv

  def initialize(report_name, list_id, csv)
    @report_name = report_name
    @list_id = list_id
    @csv = csv
  end

  def process_csv
    @list = RelateIQ::List.find(@list_id)
    failed = []
    parsed = []
    too_old = []
    CSV.new(@csv, :headers => true).each do |row|
      begin
        company = Company.new row
        if company.is_too_old?
          too_old << company
          next
        end
        next if exists(company)
        create_account_and_list_item(company)
        company.to_db(DB[:companies])
        parsed << company
      rescue => e
        failed << {company: company.name, error: e.message}
      end
    end
    [parsed, failed, too_old]
  end

  def create_account(company)
    acc = RelateIQ::Account.new
    acc.create(name: company.name)
    acc
  end

  def create_account_and_list_item(company)
    acc = create_account(company)

    fields = company.relate_iq_fields(@list)
    list_attrs = {
        :accountId => acc.id,
        :listId => @list.id,
        :name => acc.name,
        :contactIds => [''],
        :fieldValues => Hash[fields]
    }
    RelateIQ.post("lists/#{@list.id}/listitems", list_attrs.to_json)
  end


  def to_db
    DB[:imports].insert(
        :report_name => @report_name,
        :created_at => Date.today,
        :csv_content => @csv,
    )
  end

  def exists(company)
    DB[:companies].where(name: company.name).count > 0
  end

end
#encoding: utf-8
# Scheduler Server 
$stdout.sync = true
require_relative "./config/init.rb"
require 'logger' 

Scheduler = Struct.new(:scheduler)
class Scheduler
  # start a Rufus::Scheduler object if not already done
  def initialize
    self.scheduler ||= Rufus::Scheduler.start_new
  end
  
  ### OAI harvest ###
  def start_oai_harvest(params={})
    params[:start_time] ||= Time.now 
    params[:tags]       ||= "oaiharvest"
    job_id = self.scheduler.at params[:start_time], :tags => params[:tag] do
      timing_start = Time.now
      
      library = Library.new.find(:id => params[:id].to_i)
      logger.info "library oai: #{library.oai}"
      oai = OAIClient.new(library.oai["url"], 
        :format => library.oai["format"], 
        :parser => library.oai["parser"], 
        :timeout => library.oai["timeout"],
        :redirects => library.oai["redirects"])
      oai.query(:from => params[:from], :until => params[:until])
      puts "oai response: #{oai.response}"
      rdfrecords = []
      oai.response.entries.each do |record| 
        unless record.deleted?
          xmlreader = MARC::XMLReader.new(StringIO.new(record.metadata.to_s)) 
          xmlreader.each do |marc|
            rdf = RDFModeler.new(library.id, marc)
            rdf.set_type(library.config['resource']['type'])        
            rdf.convert
            rdfrecords << rdf.statements
          end
        else
          puts "deleted record: #{record.header.identifier.split(':').last}"
        end
      end
      puts "converted records: #{rdfrecords}"
      logger.info "Time to complete: #{Time.now - timing_start} s."
    end
  end
  
  # start schedule, default every five minutes
  def schedule(cron, params={})
    params[:frequency] ||= "*/5 * * * *"
    params[:tags]      ||= "test"
    cron_id = self.scheduler.cron params[:frequency], :tags => params[:tag] do 
      puts cron if cron # run script here
    end
  end
  
  def pause(job)
    self.scheduler.pause(job)
  end

  def resume(job)
    self.scheduler.resume(job)
  end
    
  def unschedule(cronjob)
    self.scheduler.unschedule(cronjob)
  end
  
  # returns a map job_id => job of at/in/every jobs  
  def find_jobs
    jobs = self.scheduler.jobs
    logger.info "running jobs: #{jobs}"
    jobs
  end

  def find_cronjobs
    jobs = self.scheduler.cron_jobs
    logger.info "scheduled cron jobs: #{jobs}"
    jobs
  end
  
  def find_all_jobs
    jobs = self.scheduler.all_jobs
    logger.info "running jobs: #{jobs}"
    jobs
  end

  def find_jobs_by_tag(t)
    jobs = self.scheduler.find_by_tag(t)
    logger.info "running jobs by tag: #{jobs}"
    jobs
  end
  
  def logger
    logger = Logger.new(File.expand_path("../logs/scheduler_#{ENV['RACK_ENV']}.log", __FILE__))
  end
end

#$SAFE = 1   # disable eval() and friends

DRb.start_service DRBSERVER, Scheduler.new
DRb.thread.join

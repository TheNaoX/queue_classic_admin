require 'spec_helper'

module QueueClassicAdmin
  describe QueueClassicAdmin::QueueClassicJobsController do
    let!(:queue_classic_job) { QueueClassicJob.create!(q_name: 'default', method: 'Time.now', args: []) }
    let!(:scheduled_job) { create_job_qc_job scheduled_at: 1.minute.from_now }

    before do
      @request.env['HTTP_REFERER'] = 'http://example.org'
    end

    it "should get index" do
      get :index, use_route: "queue_classic_admin"
      response.should be_success
      assigns(:queue_classic_jobs).should_not be_nil
    end

    context "#destroy" do
      it "should destroy queue_classic_job" do
        queue_classic_job
        expect do
          delete :destroy, id: queue_classic_job.id, use_route: "queue_classic_admin"
        end.to change(QueueClassicJob, :count).by(-1)

        expect(QueueClassicJob.where(id: scheduled_job.id).count).to eq 1
        response.code.to_i.should == 302
      end
    end

    context "#destroy_all" do
      it "should destroy everything that is not scheduled" do
        QueueClassicJob.ready.count.should == 1
        QueueClassicJob.scheduled.count.should == 1
        delete :destroy_all, use_route: "queue_classic_admin"
        QueueClassicJob.ready.count.should == 0
        QueueClassicJob.scheduled.count.should == 1
      end

      it "should destroy all in the filtered queue" do
        QueueClassicJob.create! q_name: 'foo', method: 'Time.now', args: []
        QueueClassicJob.create! q_name: 'bar', method: 'Time.now', args: []

        delete :destroy_all, use_route: "queue_classic_admin", q_name: 'foo'
        QueueClassicJob.where(q_name: 'foo').count.should == 0
        QueueClassicJob.where(q_name: 'bar').count.should == 1
      end
    end

    context "#unlock_all" do
      def lock_job job, lock_time
        job.locked_at = lock_time
        job.save!
      end

      let(:broken_time) { 10.minutes.ago }
      let(:in_progress_time) { Time.now }

      before do
        lock_job(QueueClassicJob.create!(q_name: 'bar', method: 'Time.now', args: []), broken_time)
        lock_job(QueueClassicJob.create!(q_name: 'foo', method: 'Time.now', args: []), broken_time)
        lock_job(QueueClassicJob.create!(q_name: 'foo', method: 'Time.now', args: []), in_progress_time)
      end

      it "should unlock everything not currently running" do
        delete :unlock_all, use_route: "queue_classic_admin"
        QueueClassicJob.where(locked_at: nil).count.should == 4
        QueueClassicJob.where(locked_at: in_progress_time).count.should == 1
      end

      it "should unlock all not currently running in the filtered queue" do
        delete :unlock_all, use_route: "queue_classic_admin", q_name: 'foo'
        QueueClassicJob.where(q_name: 'foo').where('locked_at IS NULL').count.should == 1
        QueueClassicJob.where(q_name: 'foo', locked_at: in_progress_time).count.should == 1
        QueueClassicJob.where(q_name: 'bar', locked_at: broken_time).count.should == 1
      end
    end

    context "#bulk_custom_action" do
      it "runs the custom action on the jobs" do
        custom_jobs = []
        QueueClassicAdmin.add_custom_bulk_action("Test") { |jobs| custom_jobs = jobs }
        job = queue_classic_job

        post :bulk_custom_action, use_route: "queue_classic_admin", custom_action: "test"

        expect(custom_jobs).to_not be_empty
      end

    end

    context "#unlock" do
      it "unlocks locked job" do
        locked_job = queue_classic_job
        locked_job.locked_at = Time.now
        locked_job.save!
        post :unlock, use_route: "queue_classic_admin", id: locked_job
        locked_job.reload.locked_at.should be_nil
      end
    end

    context "#custom" do
      it "runs the custom action" do
        custom_job = nil
        QueueClassicAdmin.add_custom_action("Test") { |job| custom_job = job }
        job = queue_classic_job

        post :custom, use_route: "queue_classic_admin", id: job, custom_action: "test"

        expect(custom_job).to_not be_nil
        expect(custom_job).to eql(job)
      end
    end
  end
end

use async_trait::async_trait;
use chrono::{DateTime, Utc};
use sqlx::PgPool;
use uuid::Uuid;

use crate::features::job::domain::{
    JobError, JobOffer, JobPaymentRecord, JobRequest, JobRepository, JobStatus,
};
use crate::features::technician::domain::TechnicianProfile;

#[derive(sqlx::FromRow)]
struct JobRequestRow {
    id: Uuid,
    client_id: Uuid,
    technician_profile_id: Option<i32>,
    tech_team_id: Option<i32>,
    job_kind: String,
    status: String,
    timeline_step: i32,
    fee_type: String,
    fee_amount: i32,
    fee_paid: bool,
    payment_method: Option<String>,
    payment_done: bool,
    mobility_included: bool,
    agreed_price: Option<i32>,
    rating: Option<i32>,
    title: Option<String>,
    address: Option<String>,
    comment: Option<String>,
    cancelled_at: Option<DateTime<Utc>>,
    cancelled_by: Option<Uuid>,
    cancellation_reason: Option<String>,
    version: i32,
    created_at: DateTime<Utc>,
}

impl TryFrom<JobRequestRow> for JobRequest {
    type Error = String;

    fn try_from(row: JobRequestRow) -> Result<Self, Self::Error> {
        let status = JobStatus::parse(&row.status)?;
        Ok(Self {
            id: row.id,
            client_id: row.client_id,
            technician_profile_id: row.technician_profile_id,
            tech_team_id: row.tech_team_id,
            job_kind: row.job_kind,
            status,
            timeline_step: row.timeline_step,
            fee_type: row.fee_type,
            fee_amount: row.fee_amount,
            fee_paid: row.fee_paid,
            payment_method: row.payment_method,
            payment_done: row.payment_done,
            mobility_included: row.mobility_included,
            agreed_price: row.agreed_price,
            rating: row.rating,
            title: row.title,
            address: row.address,
            comment: row.comment,
            cancelled_at: row.cancelled_at,
            cancelled_by: row.cancelled_by,
            cancellation_reason: row.cancellation_reason,
            version: row.version,
            created_at: row.created_at,
        })
    }
}

#[derive(sqlx::FromRow)]
struct JobOfferRow {
    id: i32,
    job_request_id: Uuid,
    technician_profile_id: i32,
    price: i32,
    eta: String,
    name: String,
    oficio: String,
    rating: f64,
    verified: bool,
}

impl From<JobOfferRow> for JobOffer {
    fn from(row: JobOfferRow) -> Self {
        Self {
            id: row.id,
            job_request_id: row.job_request_id,
            technician_profile_id: row.technician_profile_id,
            price: row.price,
            eta: row.eta,
            mono: TechnicianProfile::get_mono(&row.name),
            name: row.name,
            oficio: row.oficio,
            rating: row.rating,
            verified: row.verified,
        }
    }
}

pub struct PostgresJobRepository {
    pool: PgPool,
}

impl PostgresJobRepository {
    pub fn new(pool: PgPool) -> Self {
        Self { pool }
    }
}

#[async_trait]
impl JobRepository for PostgresJobRepository {
    async fn create_job_request(&self, job: &JobRequest) -> Result<(), JobError> {
        sqlx::query(
            "INSERT INTO job_requests (id, client_id, technician_profile_id, tech_team_id, job_kind, status, timeline_step, fee_type, fee_amount, fee_paid, payment_method, payment_done, mobility_included, agreed_price, rating, title, address, comment, cancelled_at, cancelled_by, cancellation_reason, version, created_at) \
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21, $22, $23)",
        )
        .bind(job.id)
        .bind(job.client_id)
        .bind(job.technician_profile_id)
        .bind(job.tech_team_id)
        .bind(&job.job_kind)
        .bind(job.status.as_str())
        .bind(job.timeline_step)
        .bind(&job.fee_type)
        .bind(job.fee_amount)
        .bind(job.fee_paid)
        .bind(&job.payment_method)
        .bind(job.payment_done)
        .bind(job.mobility_included)
        .bind(job.agreed_price)
        .bind(job.rating)
        .bind(&job.title)
        .bind(&job.address)
        .bind(&job.comment)
        .bind(job.cancelled_at)
        .bind(job.cancelled_by)
        .bind(&job.cancellation_reason)
        .bind(job.version)
        .bind(job.created_at)
        .execute(&self.pool)
        .await
        .map_err(|e| JobError::Repository(e.to_string()))?;

        Ok(())
    }

    async fn find_job_request_by_id(&self, id: Uuid) -> Result<Option<JobRequest>, JobError> {
        let row = sqlx::query_as::<_, JobRequestRow>(
            "SELECT id, client_id, technician_profile_id, tech_team_id, job_kind, status, timeline_step, \
             fee_type, fee_amount, fee_paid, payment_method, payment_done, mobility_included, agreed_price, rating, title, address, comment, cancelled_at, cancelled_by, cancellation_reason, version, created_at \
             FROM job_requests WHERE id = $1",
        )
        .bind(id)
        .fetch_optional(&self.pool)
        .await
        .map_err(|e| JobError::Repository(e.to_string()))?;

        match row {
            Some(r) => {
                let job = JobRequest::try_from(r).map_err(|err| JobError::Repository(err))?;
                Ok(Some(job))
            }
            None => Ok(None),
        }
    }

    async fn save_job_request(&self, job: &JobRequest) -> Result<(), JobError> {
        // The write is conditional on the version the caller read: if
        // another request got there first, this matches no rows and the
        // change is refused rather than silently overwriting theirs
        // (GAP-07). `version = version + 1` moves the row on for the next
        // writer.
        let result = sqlx::query(
            "UPDATE job_requests SET \
             technician_profile_id = $2, \
             tech_team_id = $3, \
             status = $4, \
             timeline_step = $5, \
             fee_paid = $6, \
             payment_method = $7, \
             payment_done = $8, \
             agreed_price = $9, \
             rating = $10, \
             comment = $11, \
             cancelled_at = $12, \
             cancelled_by = $13, \
             cancellation_reason = $14, \
             title = $16, \
             address = $17, \
             version = version + 1 \
             WHERE id = $1 AND version = $15",
        )
        .bind(job.id)
        .bind(job.technician_profile_id)
        .bind(job.tech_team_id)
        .bind(job.status.as_str())
        .bind(job.timeline_step)
        .bind(job.fee_paid)
        .bind(&job.payment_method)
        .bind(job.payment_done)
        .bind(job.agreed_price)
        .bind(job.rating)
        .bind(&job.comment)
        .bind(job.cancelled_at)
        .bind(job.cancelled_by)
        .bind(&job.cancellation_reason)
        .bind(job.version)
        // `title` and `address` were write-once: the INSERT set them and
        // every later UPDATE ignored them, so an edit through any future
        // use case would have been silently dropped. Included so the
        // repository persists the whole aggregate it is handed.
        .bind(&job.title)
        .bind(&job.address)
        .execute(&self.pool)
        .await
        .map_err(|e| JobError::Repository(e.to_string()))?;

        if result.rows_affected() == 0 {
            // Either someone else moved the job on, or it is gone. Both
            // mean this decision was made against stale information, and
            // both are a conflict rather than a server fault.
            return Err(JobError::ConcurrentModification);
        }

        Ok(())
    }

    async fn find_offers_by_job_id(&self, job_request_id: Uuid) -> Result<Vec<JobOffer>, JobError> {
        let rows = sqlx::query_as::<_, JobOfferRow>(
            "SELECT jo.id, jo.job_request_id, jo.technician_profile_id, jo.price, jo.eta, \
             u.name, tp.oficio, tp.rating, tp.is_verified as verified \
             FROM job_offers jo \
             JOIN technician_profiles tp ON jo.technician_profile_id = tp.id \
             JOIN users u ON tp.user_id = u.id \
             WHERE jo.job_request_id = $1",
        )
        .bind(job_request_id)
        .fetch_all(&self.pool)
        .await
        .map_err(|e| JobError::Repository(e.to_string()))?;

        Ok(rows.into_iter().map(JobOffer::from).collect())
    }

    async fn find_offer_by_id(&self, id: i32) -> Result<Option<JobOffer>, JobError> {
        let row = sqlx::query_as::<_, JobOfferRow>(
            "SELECT jo.id, jo.job_request_id, jo.technician_profile_id, jo.price, jo.eta, \
             u.name, tp.oficio, tp.rating, tp.is_verified as verified \
             FROM job_offers jo \
             JOIN technician_profiles tp ON jo.technician_profile_id = tp.id \
             JOIN users u ON tp.user_id = u.id \
             WHERE jo.id = $1",
        )
        .bind(id)
        .fetch_optional(&self.pool)
        .await
        .map_err(|e| JobError::Repository(e.to_string()))?;

        Ok(row.map(JobOffer::from))
    }

    async fn add_job_offer(&self, job_request_id: Uuid, technician_profile_id: i32, price: i32, eta: String) -> Result<(), JobError> {
        sqlx::query(
            "INSERT INTO job_offers (job_request_id, technician_profile_id, price, eta) \
             VALUES ($1, $2, $3, $4)",
        )
        .bind(job_request_id)
        .bind(technician_profile_id)
        .bind(price)
        .bind(&eta)
        .execute(&self.pool)
        .await
        .map_err(|e| JobError::Repository(e.to_string()))?;

        Ok(())
    }

    async fn find_client_history(&self, client_id: Uuid) -> Result<Vec<JobRequest>, JobError> {
        let rows = sqlx::query_as::<_, JobRequestRow>(
            "SELECT id, client_id, technician_profile_id, tech_team_id, job_kind, status, timeline_step, \
             fee_type, fee_amount, fee_paid, payment_method, payment_done, mobility_included, agreed_price, rating, title, address, comment, cancelled_at, cancelled_by, cancellation_reason, version, created_at \
             FROM job_requests WHERE client_id = $1 ORDER BY created_at DESC",
        )
        .bind(client_id)
        .fetch_all(&self.pool)
        .await
        .map_err(|e| JobError::Repository(e.to_string()))?;

        let mut jobs = Vec::new();
        for r in rows {
            let job = JobRequest::try_from(r).map_err(|err| JobError::Repository(err))?;
            jobs.push(job);
        }
        Ok(jobs)
    }

    async fn find_assigned_jobs(&self, technician_profile_id: i32) -> Result<Vec<JobRequest>, JobError> {
        let rows = sqlx::query_as::<_, JobRequestRow>(
            "SELECT id, client_id, technician_profile_id, tech_team_id, job_kind, status, timeline_step, \
             fee_type, fee_amount, fee_paid, payment_method, payment_done, mobility_included, agreed_price, rating, title, address, comment, cancelled_at, cancelled_by, cancellation_reason, version, created_at \
             FROM job_requests WHERE technician_profile_id = $1 ORDER BY created_at DESC",
        )
        .bind(technician_profile_id)
        .fetch_all(&self.pool)
        .await
        .map_err(|e| JobError::Repository(e.to_string()))?;

        let mut jobs = Vec::new();
        for r in rows {
            let job = JobRequest::try_from(r).map_err(|err| JobError::Repository(err))?;
            jobs.push(job);
        }
        Ok(jobs)
    }

    async fn find_open_bidding_jobs(&self, excluding_technician_profile_id: i32) -> Result<Vec<JobRequest>, JobError> {
        let rows = sqlx::query_as::<_, JobRequestRow>(
            "SELECT id, client_id, technician_profile_id, tech_team_id, job_kind, status, timeline_step, \
             fee_type, fee_amount, fee_paid, payment_method, payment_done, mobility_included, agreed_price, rating, title, address, comment, cancelled_at, cancelled_by, cancellation_reason, version, created_at \
             FROM job_requests \
             WHERE job_kind = 'bidding' AND status = 'pending' AND technician_profile_id IS NULL \
             AND id NOT IN (SELECT job_request_id FROM job_offers WHERE technician_profile_id = $1) \
             ORDER BY created_at DESC",
        )
        .bind(excluding_technician_profile_id)
        .fetch_all(&self.pool)
        .await
        .map_err(|e| JobError::Repository(e.to_string()))?;

        let mut jobs = Vec::new();
        for r in rows {
            let job = JobRequest::try_from(r).map_err(|err| JobError::Repository(err))?;
            jobs.push(job);
        }
        Ok(jobs)
    }

    async fn record_job_payment(&self, payment: &JobPaymentRecord) -> Result<(), JobError> {
        sqlx::query(
            "INSERT INTO job_payments \
             (job_request_id, gateway, gateway_reference, amount_soles, payment_method, status, idempotency_key, simulated) \
             VALUES ($1, $2, $3, $4, $5, 'captured', $6, $7)",
        )
        .bind(payment.job_request_id)
        .bind(&payment.gateway)
        .bind(&payment.gateway_reference)
        .bind(payment.amount_soles)
        .bind(&payment.payment_method)
        .bind(payment.idempotency_key)
        .bind(payment.simulated)
        .execute(&self.pool)
        .await
        .map_err(|e| JobError::Repository(e.to_string()))?;

        Ok(())
    }

    async fn find_job_payment_by_idempotency_key(
        &self,
        idempotency_key: Uuid,
    ) -> Result<Option<JobPaymentRecord>, JobError> {
        let row = sqlx::query_as::<_, JobPaymentRow>(
            "SELECT job_request_id, gateway, gateway_reference, amount_soles, payment_method, idempotency_key, simulated \
             FROM job_payments WHERE idempotency_key = $1",
        )
        .bind(idempotency_key)
        .fetch_optional(&self.pool)
        .await
        .map_err(|e| JobError::Repository(e.to_string()))?;

        Ok(row.map(|r| JobPaymentRecord {
            job_request_id: r.job_request_id,
            gateway: r.gateway,
            gateway_reference: r.gateway_reference,
            amount_soles: r.amount_soles,
            payment_method: r.payment_method,
            idempotency_key: r.idempotency_key,
            simulated: r.simulated,
        }))
    }
}

#[derive(sqlx::FromRow)]
struct JobPaymentRow {
    job_request_id: Uuid,
    gateway: String,
    gateway_reference: String,
    amount_soles: i32,
    payment_method: String,
    idempotency_key: Uuid,
    simulated: bool,
}

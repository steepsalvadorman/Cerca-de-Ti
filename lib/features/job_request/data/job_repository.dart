import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../domain/job_offer.dart';
import '../domain/job_request.dart';

class PayFeeResult {
  const PayFeeResult({required this.simulated, required this.gatewayReference});

  final bool simulated;
  final String gatewayReference;
}

class TechnicianJobsBundle {
  const TechnicianJobsBundle({required this.assigned, required this.openForBid});

  final List<JobRequest> assigned;
  final List<JobRequest> openForBid;
}

/// Talks to the `job` feature of the backend (`/jobs`, `/jobs/{id}/...`,
/// `/client/history`, `/technician/jobs`).
class JobRepository {
  JobRepository(this._dio);

  final Dio _dio;

  Future<JobRequest> createJob({
    int? technicianProfileId,
    int? techTeamId,
    required String jobKind,
    String? title,
    String? address,
    bool? mobilityIncluded,
  }) async {
    try {
      final response = await _dio.post('/jobs', data: {
        'technician_profile_id': technicianProfileId,
        'tech_team_id': techTeamId,
        'job_kind': jobKind,
        'title': title,
        'address': address,
        'mobility_included': mobilityIncluded,
      });
      return JobRequest.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw apiExceptionOf(e);
    }
  }

  Future<JobRequest> getJob(String jobId) async {
    try {
      final response = await _dio.get('/jobs/$jobId');
      return JobRequest.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw apiExceptionOf(e);
    }
  }

  Future<PayFeeResult> payFee(String jobId, String paymentMethod) async {
    try {
      final response = await _dio.post('/jobs/$jobId/pay', data: {'payment_method': paymentMethod});
      final data = response.data as Map<String, dynamic>;
      return PayFeeResult(
        simulated: data['simulated'] as bool? ?? false,
        gatewayReference: data['gateway_reference'] as String? ?? '',
      );
    } on DioException catch (e) {
      throw apiExceptionOf(e);
    }
  }

  Future<void> advance(String jobId) async {
    try {
      await _dio.post('/jobs/$jobId/advance');
    } on DioException catch (e) {
      throw apiExceptionOf(e);
    }
  }

  Future<void> rate(String jobId, int rating, {String? comment}) async {
    try {
      await _dio.post('/jobs/$jobId/rate', data: {'rating': rating, 'comment': comment});
    } on DioException catch (e) {
      throw apiExceptionOf(e);
    }
  }

  Future<List<JobOffer>> getOffers(String jobId) async {
    try {
      final response = await _dio.get('/jobs/$jobId/offers');
      return (response.data as List).map((e) => JobOffer.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw apiExceptionOf(e);
    }
  }

  Future<void> chooseOffer(String jobId, int offerId) async {
    try {
      await _dio.post('/jobs/$jobId/offers/choose', data: {'offer_id': offerId});
    } on DioException catch (e) {
      throw apiExceptionOf(e);
    }
  }

  Future<void> submitOffer(String jobId, {required int price, required String eta}) async {
    try {
      await _dio.post('/jobs/$jobId/offers', data: {'price': price, 'eta': eta});
    } on DioException catch (e) {
      throw apiExceptionOf(e);
    }
  }

  Future<TechnicianJobsBundle> getTechnicianJobs() async {
    try {
      final response = await _dio.get('/technician/jobs');
      final data = response.data as Map<String, dynamic>;
      return TechnicianJobsBundle(
        assigned: (data['assigned'] as List).map((e) => JobRequest.fromJson(e as Map<String, dynamic>)).toList(),
        openForBid: (data['open_for_bid'] as List).map((e) => JobRequest.fromJson(e as Map<String, dynamic>)).toList(),
      );
    } on DioException catch (e) {
      throw apiExceptionOf(e);
    }
  }

  Future<List<JobRequest>> getClientHistory() async {
    try {
      final response = await _dio.get('/client/history');
      return (response.data as List).map((e) => JobRequest.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw apiExceptionOf(e);
    }
  }
}

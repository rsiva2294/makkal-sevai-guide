// A helper class to hold flattened, searchable information about a service.
class ServiceInfo {
  final String departmentName;
  final String departmentNameEn;
  final String serviceName;
  final String serviceNameEn;
  final List<String> eligibility;
  final List<String> eligibilityEn;
  final List<String> documents;
  final List<String> documentsEn;
  final String type; // "Rural" or "Urban"

  ServiceInfo({
    required this.departmentName,
    required this.departmentNameEn,
    required this.serviceName,
    required this.serviceNameEn,
    required this.eligibility,
    required this.eligibilityEn,
    required this.documents,
    required this.documentsEn,
    required this.type,
  });

  // Factory constructor to create a ServiceInfo instance from JSON data.
  factory ServiceInfo.fromJson(Map<String, dynamic> departmentJson, Map<String, dynamic> serviceJson, String type) {
    List<String> parseStringOrList(dynamic field) {
      if (field == null) return [];
      if (field is String && field.isNotEmpty) return [field];
      if (field is List) return field.map((e) => e.toString()).toList();
      return [];
    }

    List<String> safeCast(List<dynamic> list) {
      return list.map((e) => e.toString()).toList();
    }

    return ServiceInfo(
      departmentName: departmentJson['department'] ?? 'N/A',
      departmentNameEn: departmentJson['department_en'] ?? 'N/A',
      serviceName: serviceJson['name'] ?? 'N/A',
      serviceNameEn: serviceJson['name_en'] ?? 'N/A',
      eligibility: parseStringOrList(serviceJson['eligibility']),
      eligibilityEn: parseStringOrList(serviceJson['eligibility_en']),
      documents: serviceJson['documents'] != null ? safeCast(serviceJson['documents']) : [],
      documentsEn: serviceJson['documents_en'] != null ? safeCast(serviceJson['documents_en']) : [],
      type: type,
    );
  }
}
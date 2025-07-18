import 'package:makkal_sevai_guide/model/service_info.dart';

class DepartmentData {
  final String departmentName;
  final String departmentNameEn;
  final String type; // "Rural" or "Urban"
  final List<ServiceInfo> services; // List of services under this department

  DepartmentData({
    required this.departmentName,
    required this.departmentNameEn,
    required this.type,
    required this.services,
  });
}
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:makkal_sevai_guide/model/service_info.dart';

// A widget to display the details of a selected service in a card format.
class ServiceDetailCard extends StatelessWidget {
  final ServiceInfo service;
  final bool isEnglish;

  const ServiceDetailCard({
    super.key,
    required this.service,
    required this.isEnglish,
  });

  List<String> _getDisplayList({
    required List<String> englishList,
    required List<String> tamilList,
    required String noDataEnglish,
    required String noDataTamil,
  }) {
    if (isEnglish) {
      return englishList.isNotEmpty ? englishList : [noDataEnglish];
    } else {
      return tamilList.isNotEmpty ? tamilList : [noDataTamil];
    }
  }

  void _copyToClipboard(BuildContext context) {
    final eligibilityList = _getDisplayList(
      englishList: service.eligibilityEn,
      tamilList: service.eligibility,
      noDataEnglish: 'No specific eligibility criteria listed.',
      noDataTamil: 'குறிப்பிட்ட தகுதி வரம்புகள் எதுவும் பட்டியலிடப்படவில்லை.',
    );

    final documentsList = _getDisplayList(
      englishList: service.documentsEn,
      tamilList: service.documents,
      noDataEnglish: 'No specific documents listed.',
      noDataTamil: 'குறிப்பிட்ட ஆவணங்கள் எதுவும் பட்டியலிடப்படவில்லை.',
    );

    final String textToCopy = """
${isEnglish ? 'Service' : 'சேவை'}: ${isEnglish ? service.serviceNameEn : service.serviceName}
${isEnglish ? 'Department' : 'துறை'}: ${isEnglish ? service.departmentNameEn : service.departmentName}
--------------------
${isEnglish ? 'Eligibility' : 'தகுதி'}:
${eligibilityList.map((e) => '- $e').join('\n')}
--------------------
${isEnglish ? 'Documents Required' : 'தேவையான ஆவணங்கள்'}:
${documentsList.map((e) => '- $e').join('\n')}
""";

    Clipboard.setData(ClipboardData(text: textToCopy)).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isEnglish ? 'Copied to clipboard!' : 'கிளிப்போர்டுக்கு நகலெடுக்கப்பட்டது!')),
      );
    });

    // Analytics for Copy to Clipboard
    FirebaseAnalytics.instance.logEvent(
      name: 'copy_details_clicked',
      parameters: {
        'service_name_en': service.serviceNameEn,
        'language': isEnglish ? 'English' : 'Tamil',
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ruralColor = isDark ? Colors.green.shade800 : Colors.green.shade100;
    final urbanColor = isDark ? Colors.blue.shade800 : Colors.blue.shade100;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEnglish ? service.serviceNameEn : service.serviceName,
                        style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        isEnglish ? service.serviceName : service.serviceNameEn,
                        style: textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_all_outlined),
                  onPressed: () => _copyToClipboard(context),
                  tooltip: 'Copy Details',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Chip(
              label: Text(service.type),
              backgroundColor: service.type == 'Rural' ? ruralColor : urbanColor,
              avatar: Icon(service.type == 'Rural' ? Icons.grass : Icons.location_city),
            ),
            const Divider(height: 24),

            _buildDetailSection(
              context,
              icon: Icons.account_balance,
              title: isEnglish ? 'Department' : 'துறை',
              content: [isEnglish ? service.departmentNameEn : service.departmentName],
            ),

            _buildDetailSection(
              context,
              icon: Icons.check_circle_outline,
              title: isEnglish ? 'Eligibility' : 'தகுதி',
              content: _getDisplayList(
                englishList: service.eligibilityEn,
                tamilList: service.eligibility,
                noDataEnglish: 'No specific eligibility criteria listed.',
                noDataTamil: 'குறிப்பிட்ட தகுதி வரம்புகள் எதுவும் பட்டியலிடப்படவில்லை.',
              ),
            ),

            _buildDetailSection(
              context,
              icon: Icons.description_outlined,
              title: isEnglish ? 'Documents Required' : 'தேவையான ஆவணங்கள்',
              content: _getDisplayList(
                englishList: service.documentsEn,
                tamilList: service.documents,
                noDataEnglish: 'No specific documents listed.',
                noDataTamil: 'குறிப்பிட்ட ஆவணங்கள் எதுவும் பட்டியலிடப்படவில்லை.',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailSection(BuildContext context, {required IconData icon, required String title, required List<String> content}) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(title, style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          ...content.map((item) => Padding(
            padding: const EdgeInsets.only(left: 28.0, bottom: 4.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                Expanded(child: Text(item, style: textTheme.bodyMedium)),
              ],
            ),
          )),
        ],
      ),
    );
  }
}
// lib/screen/department_overview.dart

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

// Screen for displaying department overviews (brochures)
class DepartmentOverviewScreen extends StatefulWidget {
  final bool isEnglish;
  const DepartmentOverviewScreen({super.key, required this.isEnglish});

  @override
  State<DepartmentOverviewScreen> createState() => _DepartmentOverviewScreenState();
}

class _DepartmentOverviewScreenState extends State<DepartmentOverviewScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _ruralDownloadUrl;
  String? _urbanDownloadUrl;
  bool _isLoadingUrls = true;

  // Define paths to your images in Firebase Storage
  final String _ruralBrochureStoragePath = 'brochure/rural.jpg'; // *** Adjust this path ***
  final String _urbanBrochureStoragePath = 'brochure/urban.jpg'; // *** Adjust this path ***

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadDownloadUrls();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDownloadUrls() async {
    try {
      debugPrint("Attempting to load brochure URLs from Firebase Storage...");
      final ruralRef = FirebaseStorage.instance.ref(_ruralBrochureStoragePath);
      final urbanRef = FirebaseStorage.instance.ref(_urbanBrochureStoragePath);

      _ruralDownloadUrl = await ruralRef.getDownloadURL();
      _urbanDownloadUrl = await urbanRef.getDownloadURL();

      debugPrint("Rural Brochure URL: $_ruralDownloadUrl");
      debugPrint("Urban Brochure URL: $_urbanDownloadUrl");

    } catch (e) {
      debugPrint("Error loading brochure download URLs: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isEnglish ? 'Failed to load brochure images.' : 'பிரசுரப் படங்களை ஏற்ற முடியவில்லை.',
            ),
          ),
        );
      }
      // Analytics for failure to load brochure URLs
      FirebaseAnalytics.instance.logEvent(
        name: 'brochure_url_load_failed',
        parameters: {
          'error': e.toString(),
          'language': widget.isEnglish ? 'English' : 'Tamil',
        },
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingUrls = false;
        });
      }
    }
  }

  // Function to launch the URL of the brochure
  Future<void> _launchImageUrl(String imageUrl, String brochureType) async {
    final uri = Uri.parse(imageUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isEnglish ? 'Could not open the brochure.' : 'வளையலை திறக்க முடியவில்லை.',
            ),
          ),
        );
      }
      // Log failure to open brochure
      FirebaseAnalytics.instance.logEvent(
        name: 'brochure_open_failed',
        parameters: {
          'brochure_url': imageUrl,
          'brochure_type': brochureType,
          'reason': 'could_not_launch',
          'language': widget.isEnglish ? 'English' : 'Tamil',
        },
      );
    } else {
      // Analytics for Successful Brochure Open
      FirebaseAnalytics.instance.logEvent(
        name: 'brochure_opened',
        parameters: {
          'brochure_url': imageUrl,
          'brochure_type': brochureType, // e.g., 'rural' or 'urban'
          'language': widget.isEnglish ? 'English' : 'Tamil',
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEnglish ? 'Open Brochure' : 'வளையலை திறக்க'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: widget.isEnglish ? 'Rural' : 'கிராமப்புறம்'),
            Tab(text: widget.isEnglish ? 'Urban' : 'நகர்ப்புறம்'),
          ],
        ),
      ),
      body: _isLoadingUrls
          ? const Center(child: CircularProgressIndicator())
          : Column( // Wrap TabBarView and Disclaimer in a Column
        children: [
          Expanded( // TabBarView takes remaining space
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildBrochureView(_ruralDownloadUrl, 'rural'), // Pass type
                _buildBrochureView(_urbanDownloadUrl, 'urban'), // Pass type
              ],
            ),
          ),
          // Disclaimer Banner (copied from ServiceFinderScreen)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.5),
            child: Text(
              widget.isEnglish
                  ? "Brochure obtained from the official Ungaludan Stalin website. Not owned by this app."
                  : "இந்த வளையலை உங்களுடன் ஸ்டாலின் இணையதளத்திலிருந்து பெறப்பட்டது. இது இந்த செயலியின் சொந்தம் அல்ல.",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrochureView(String? imageUrl, String brochureType) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return Center(
        child: Text(
          widget.isEnglish ? 'Brochure not available.' : 'வளையலை கிடைக்கவில்லை.',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      );
    }
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Display the image (optional, you could just have a button)
            Image.network(
              imageUrl,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Center(
                  child: Text(
                    widget.isEnglish ? 'Error loading image preview.' : 'பட முன்னோட்டத்தை ஏற்றும் பிழை.',
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _launchImageUrl(imageUrl, brochureType), // Pass brochureType here
              icon: const Icon(Icons.open_in_new),
              label: Text(widget.isEnglish ? 'Open Brochure' : 'வளையலை திறக்க'),
            ),
            const SizedBox(height: 10),
            Text(
              widget.isEnglish
                  ? 'Tap "Open Brochure" to view it in your default browser or image viewer.'
                  : 'உங்கள் இயல்புநிலை உலாவி அல்லது பட வியூவரில் காண "வளையலை திறக்க" என்பதைத் தட்டவும்.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}